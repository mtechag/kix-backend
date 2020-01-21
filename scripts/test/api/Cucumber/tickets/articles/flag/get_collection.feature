Feature: the /tickets/:TicketID/articles/:ArticleID/flags resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing article flags
    Given a ticket
    Then the response code is 201
    Given a article
    Then the response code is 201
    When I query the article flags collection
    Then the response code is 200
    When I delete this ticket
    Then the response code is 204
    And the response has no content