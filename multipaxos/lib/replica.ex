
# Thibault Meunier (ttm17)

defmodule Replica do

def start config, database, monitor do
  receive do
  { :bind, leaders } ->
    next config, monitor, 1, 1, MapSet.new, %{}, %{}, database, leaders
  end
end

defp next config, monitor, slot_in, slot_out, requests, proposals, decisions, database, leaders do
  { slot_out, requests, proposals, decisions } =
    receive do
    { :request, cmd } ->
      send monitor, { :client_request, config.server_num }
      { slot_out, (MapSet.put requests, cmd), proposals, decisions }
    { :decision, slot, cmd } ->
      decisions = Map.put decisions, slot, cmd
      { slot_out, requests, proposals } =
        while_slot_out config, slot_out, requests, proposals, decisions, database
      { slot_out, requests, proposals, decisions }
    end
  { slot_in, requests, proposals, leaders } =
    propose config, slot_in, slot_out, requests, proposals, decisions, leaders
  next config, monitor, slot_in, slot_out, requests, proposals, decisions, database, leaders
end

defp propose config, slot_in, slot_out, requests, proposals, decisions, leaders do
  if slot_in < slot_out + config.window and MapSet.size(requests) > 0 do
    cmd = hd(MapSet.to_list requests)
    { client, id, transaction } = cmd

    if slot_in > config.window and Map.has_key?(decisions, slot_in - config.window) and isreconfig?(transaction) do
      #leaders = leaders
    end

    { requests, proposals } =
      if not (Map.has_key? decisions, slot_in) do
        requests = MapSet.delete requests, cmd
        proposals = Map.put proposals, slot_in, cmd
        for leader <- leaders do
          send leader, { :propose, slot_in, cmd }
        end
        { requests, proposals }
      else
        { requests, proposals }
      end
    slot_in = slot_in + 1

    propose config, slot_in, slot_out, requests, proposals, decisions, leaders
  else
    { slot_in, requests, proposals, leaders }
  end
end

defp perform config, cmd, slot_out, decisions, database do
  cmd = decisions[slot_out]
  { client, id, transaction } = cmd

  exist = Enum.reduce 1..(slot_out-1), false, fn s, acc ->
            acc or ((Map.has_key? decisions, s) and decisions[s] === cmd)
          end

  # Return slot_out + 1
  if exist or isreconfig?(transaction) do
     slot_out + 1
  else
    { client, cid, transaction } = cmd
    send database, { :execute, transaction }
    slot_out = slot_out + 1
    result = transaction # result may also be the current state of the database
    send client, { :reply, cid, result }
    slot_out
  end
end

defp while_slot_out config, slot_out, requests, proposals, decisions, database do
  if Map.has_key? decisions, slot_out do
    cmd = decisions[slot_out]
    { requests, proposals } =
      if Map.has_key? proposals, slot_out do
        cmd_bis = proposals[slot_out]
        proposals = Map.delete proposals, slot_out
        requests =
          if cmd_bis !== cmd do
            MapSet.put requests, cmd_bis
          else
            requests
          end
        { requests, proposals }
      else
        { requests, proposals }
      end
    slot_out = perform config, cmd, slot_out, decisions, database
    while_slot_out config, slot_out, requests, proposals, decisions, database
  else
    { slot_out, requests, proposals }
  end
end

defp isreconfig? transaction do
  # no reconfig possible, implement :reconfig if you want
  false
end

end # module ----------
