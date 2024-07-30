ExUnit.start()

TestAgent.start_link()

EfxCase.omnipresent(
  EfxCase.EfxOmnipresentExample,
  get: fn -> [42] end,
  another_get: fn -> ["foo"] end
)
