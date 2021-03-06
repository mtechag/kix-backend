Feature: GET request to the /tickets/:TicketID/articles/:ArticleID/attachments resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing attachments
    Given a ticket
    Then the response code is 201
    Given a article
    Then the response code is 201
    Given a article attachment
    Then the response code is 201
    When I query the attachments collection
    Then the response code is 200
    When I delete this ticket
    Then the response code is 204
    And the response has no content 


