
# Thibault Meunier (ttm17)

defmodule Commander do

def start config, leader, acceptors, replicas, { ballot, slot, cmd } do
  waitfor = 
    Enum.reduce acceptors, MapSet.new, fn acceptor, acc ->
      (send acceptor, { :p2a, self, { ballot, slot, cmd } };
      MapSet.put acc, acceptor)
    end

  next config, waitfor, leader, acceptors, replicas, { ballot, slot, cmd }
end

defp next config, waitfor, leader, acceptors, replicas, { ballot, slot, cmd } do
  receive do
  { :p2b, acceptor, proposed_ballot } ->
    if proposed_ballot === ballot do
      waitfor = MapSet.delete waitfor, acceptor
      if MapSet.size(waitfor) <  length(acceptors)/2 do
        for replica <- replicas do
          send replica, { :decision, slot, cmd }
        end
        kill leader
      else
        next config, waitfor, leader, acceptors, replicas, { ballot, slot, cmd }
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
