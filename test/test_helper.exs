Code.require_file("test/support/setup.ex")

Drops.Relation.Cache.clear_all()

Code.require_file("support/doctest_case.ex", __DIR__)
Code.require_file("support/relation_case.ex", __DIR__)

ExUnit.start()
