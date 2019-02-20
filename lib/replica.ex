# Hang Li Li (hl4716)

defmodule Replica do

  defmodule ReplicaState do
    defstruct config: Map.new,
              database: nil,
              monitor: nil,
              leaders: [],
              slot_in: 1,
              slot_out: 1,
              requests: [],
              proposals: Map.new(),
              decisions: Map.new()
  end

  def start(config, database, monitor) do
    receive do
      { :bind, leaders } ->
        %ReplicaState{
          config: config,
          database: database,
          monitor: monitor,
          leaders: leaders
        }
        |> next
    end
  end

  defp propose(state) do
    if (state.slot_in < state.slot_out + state.config.window) &&
       not Enum.empty?(state.requests) do

      state = if not Map.has_key?(state.decisions, state.slot_in) do
        { c, requests } = List.pop_at(state.requests, 0)
        proposals = Map.put(state.proposals, state.slot_in, c)
        for leader <- state.leaders do
          send leader, { :propose, state.slot_in, c }
        end
        state = %{ state | requests: requests, proposals: proposals }
      else
        state
      end

      next(%{ state | slot_in: state.slot_in + 1 })
    else
      state
    end
  end

  defp perform(state, { client, request_id, transaction } = command) do
    if has_already_executed(state.slot_out, command, state.decisions) do
      state.slot_out + 1
    else
      send state.database, { :execute, transaction }
      send client, { :response, request_id, :completed }
      state.slot_out + 1
    end
  end

  defp has_already_executed(slot_out, command, decisions) do
    Enum.reduce(decisions, false, fn({ s, c }), acc ->
      acc || (c == command && s < slot_out)
    end)
  end

  defp next(state) do
    receive do
      { :client_request, command } ->
        # first element is most recently added
        send state.monitor, { :client_request, state.config.server_num }
        %{state | requests: [command | state.requests] }

      { :decision, slot, command } ->
        execute_commands(%{ state | decisions: Map.put(state.decisions, slot, command) })

    end
    |> propose
    |> next
  end

  defp execute_commands(state) do
    if not Map.has_key?(state.decisions, state.slot_out) do
      state
    else
      decision_c = Map.get(state.decisions, state.slot_out)
      { proposal_c, proposals } = Map.pop(state.proposals, state.slot_out)

      state = if (proposal_c != nil) && (proposal_c != decision_c) do
        %{ state | requests: [proposal_c | state.requests], proposals: proposals }
      else
        %{ state | proposals: proposals }
      end

      %{ state | slot_out: perform(state, decision_c) }
      |> execute_commands
    end
  end

end
