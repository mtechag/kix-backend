 Feature: GET request to the /session/user/preferences resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing session user preferences
    When I query the collection of session user preferences
    Then the response code is 200


