 Feature: GET request to the /system/communication/notifications resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing notifications 
    When I query the collection of notifications 
    Then the response code is 200
    Then the response contains 11 items of type "Notification"
    And the response contains the following items of type Notification
      | Name                                   | ValidID |
      | Agent - New Ticket Notification        | 1       |
      | Agent - Reminder (if unlocked)         | 1       |
      | Customer - New Ticket Receipt          | 1       |
      | Agent - FUP Notification (if unlocked) | 1       |      
      | Agent - FUP Notification (if locked)   | 1       |      
      | Agent - Lock Timeout                   | 1       |
      | Agent - Owner Assginment               | 1       |
      | Agent - Responsible Assignment         | 1       |           
      | Agent - New Note Notification          | 1       | 
      | Agent - Ticket Move Notification       | 1       |
      | Agent - Reminder (if locked)           | 1       |     