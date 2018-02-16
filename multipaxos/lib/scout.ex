
# Thibault Meunier (ttm17)

defmodule Scout do

def start config, leader, acceptors, ballot do
  waitfor = 
    Enum.reduce acceptors, MapSet.new, fn acceptor, acc ->
      (send acceptor, { :p1a, self, ballot };
      MapSet.put acc, acceptor)
    end
  pvalues = []

  next config, waitfor, pvalues, leader, acceptors, ballot
end

defp next config, waitfor, pvalues, leader, acceptors, ballot do
  receive do
  { :p1b, acceptor, proposed_ballot, accepted } ->
    if proposed_ballot === ballot do
      pvalues = pvalues ++ accepted
      waitfor = MapSet.delete waitfor, acceptor
      if MapSet.size(waitfor) < length(acceptors)/2 do
        send leader, { :adopted, ballot, pvalues }
        kill leader
      else
        next config, waitfor, pvalues, leader, acceptors, ballot
      end
    else
      send leader, { :preempted, proposed_ballot }
      kill leader
    end
  end
end

defp kill leader do
  send leader, { :kill, self }
end

end # module ----------
