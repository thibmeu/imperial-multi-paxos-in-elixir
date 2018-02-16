
# Thibault Meunier (ttm17)

defmodule Acceptor do

def start config do
  next config, None, []
end

defp next config, ballot, accepted do
  receive do
  { :p1a, src, proposed_ballot } ->
    ballot = if proposed_ballot > ballot, do: proposed_ballot, else: ballot
    send src, { :p1b, self, ballot, accepted }
    next config, ballot, accepted
  { :p2a, src, { proposed_ballot, slot, cmd } = msg } ->
    accepted = if proposed_ballot === ballot, do: (accepted ++ [ msg ]), else: accepted
    send src, { :p2b, self, ballot}
    next config, ballot, accepted
  end
end

end # module ----------
