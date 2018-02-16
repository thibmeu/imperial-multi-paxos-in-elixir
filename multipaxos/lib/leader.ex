
# Thibault Meunier (ttm17)

defmodule Leader do

def start config do
  ballot = { 0, self }
  active = false
  proposals = %{}

  receive do
  { :bind, acceptors, replicas } ->
    scout config, acceptors, ballot
    next config, ballot, active, proposals, acceptors, replicas
  end
end

defp next config, ballot, active, proposals, acceptors, replicas do
  receive do
  { :propose, slot, cmd } ->
    proposals = 
      if not (Map.has_key? proposals, slot) do
        proposals = Map.put proposals, slot, cmd
        if active do
          commander config, acceptors, replicas, { ballot, slot, cmd }
        end
        proposals
      else
        proposals
      end
    next config, ballot, active, proposals, acceptors, replicas
  { :adopted, ballot, pvalues } ->
    { pmax, proposals } =
      Enum.reduce pvalues, { %{}, proposals }, fn value, { pmax, props } = acc ->
        (
          { vballot, vslot, vcmd } = value;
          if (Map.has_key? pmax, vslot) or pmax[vslot] < vballot do
            pmax = Map.put pmax, vslot, vballot
            props = Map.put props, vslot, vcmd
            { pmax, props }
          else
            acc
          end
        )
      end
    for proposal <- proposals do
      { slot, cmd } = proposal
      commander config, acceptors, replicas, { ballot, slot, cmd }
    end
    active = true
    next config, ballot, active, proposals, acceptors, replicas
  { :preempted, { lballot, leader } = proposed_ballot } ->
    { ballot, active } =
      if proposed_ballot  > ballot do
        active = false
        ballot = { lballot + 1, self }
        scout config, acceptors, ballot
        { ballot, active }
      else
        { ballot, active }
      end
    next config, ballot, active, proposals, acceptors, replicas
  { :kill, pid } ->
    Process.exit pid, :kill
    next config, ballot, active, proposals, acceptors, replicas
  end
end

defp scout config, acceptors, ballot do
  spawn Scout, :start, [ config, self, acceptors, ballot ]
end

defp commander config, acceptors, replicas, { ballot, slot, cmd } do
  spawn Commander, :start, [ config, self, acceptors, replicas, { ballot, slot, cmd } ]
end

end # module ----------
