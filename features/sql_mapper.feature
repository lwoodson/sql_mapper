Feature: map raw sql to lightweight objects
  Background:
    Given a connection to sqlite3 database :memory:
    And a table named foos with 100 records

  Scenario:
    When I fetch foos using inline sql
    Then my results should have 100 foos each coerced into a Struct

  Scenario:
    When I fetch foos using inline sql and Hash result_class
    Then my results should have 100 foos each coerced into a Hash

  Scenario:
    When I fetch foos using a query named all_foos
    Then my results should have 100 foos each coerced into a Struct

  Scenario:
    When I fetch foos using a query named all_foos and Hash result_class
    Then my results should have 100 foos each coerced into a Hash

  Scenario:
    When I fetch_one foo with id 1 using inline sql
    Then my result should be a foo with id 1 coerced into a Struct

  Scenario:
    When I fetch_one foo with id 1 using a query named a_foo
    Then my result should be a foo with id 1 coerced into a Struct
