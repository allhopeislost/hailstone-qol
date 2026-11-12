-- Pet chain driver: the chain only matters in game, and this script's window callbacks run every frame, so one
-- hidden callback per frame is enough to tick it. The actual logic lives in core/petchain.lua on the plugin side
-- (mq.TLO, the packet hooks); this file only calls petchain_tick, which throttles itself to its own tick rate.
ui.window("PetChain", function()
  if not eq.InGame() then return end
  local qol = eq.Plugin("script:qol")
  if qol and type(qol.petchain_tick) == "function" then
    qol.petchain_tick()
  end
end)
