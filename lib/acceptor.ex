# Hang Li Li (hl4716)

defmodule Acceptor do

  def start(config) do
    next(-1, MapSet.new())
  end

  defp next(ballot_num, accepted) do
    receive do
      { :p1a, leader_id, b } ->
        ballot_num = max(b, ballot_num)
        send leader_id, { :p1b, self(), ballot_num, accepted }
        next(ballot_num, accepted)

      { :p2a, leader_id, pvalue }->
        accepted = update_accepted(accepted, ballot_num, pvalue)
        send leader_id, { :p2b, self(), ballot_num }
        next(ballot_num, accepted)

      end
  end

  defp update_accepted(accepted, ballot_num, { b, _, _ } = pvalue) do
    if (b == ballot_num) do
      MapSet.put(accepted, pvalue)
    else
      accepted
    end
  end


end
