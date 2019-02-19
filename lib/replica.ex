# Hang Li Li (hl4716)

defmodule Replica do

  def start(config, database, monitor) do
    receive do
      { :bind, leaders } ->
        next(leaders, database, 1, 1, MapSet.new(), MapSet.new(), MapSet.new())
    end
  end

  defp propose() do

  end

  defp perform() do

  end

  defp next(leaders, database, slot_in, slot_out, requests, proposals, decisions) do
    receive do
      { :request, command } ->
        requests = MapSet.put(requests, command)
        propose()
        next(leaders, database, slot_in, slot_out, requests, proposals, decisions)

      { :decision, slot, command } ->
        decisions = MapSet.put(decisions, { slot, command })
        for { _, c } <- get_slots(slot_out, decisions) do


        end
        propose()
        next(leaders, database, slot_in, slot_out, requests, proposals, decisions)

      end
  end

  defp get_slots(slot, proposals) do
    Enum.reduce(proposals, false, fn({ s, _ }), acc ->
      acc || (s == slot)
    end)
  end

end
