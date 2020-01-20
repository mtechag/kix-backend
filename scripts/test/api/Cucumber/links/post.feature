Feature: POST request to the /links resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a link
    When I create a link
    Then the response code is 201
    And the response object is LinkPostResponse
    When I delete this link
    Then the response code is 204

