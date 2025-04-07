# Τhis configures Mox to use the MockClashApi module as the API implementation in tests.
Mox.defmock(MockClashApi, for: Iclash.ClashApi)
