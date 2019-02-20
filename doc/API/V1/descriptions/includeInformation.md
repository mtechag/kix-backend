When requesting items it is possible to include more information into the response than the base object data. To do this you can use the optional query parameter ```include```. Every resource can always include its own direct sub-resources. What exactly can be included additionally, depends on the actual resource you are querying. Therefore it will be documented in the description of the resource. 

** Usage in URL **
``` bash
    .../<resource>?include=<What>
```


** Explanation **

|Parameter|Required?|Description|
|-|:-:|-|
|```<What>```|yes|The additional data to include into the response. You can separate multiple ones by comma.|

There are some generic includes that can be used in every query regardless of a specific resource. At the moment those generic includes are: 

|Generic Include|Description|
|-|-|
|```Links```|Include all the the linked objects of this item.|
|```ObjectIcon```|Include the icon for this item.|

Please note that the include extends each item in the response with an additional attribute that is named like the include itself. Also the including of data that is not related to sub-resources sometimes results in a list of IDs of the relevant objects. Please see the optional function [```expand```](#expand_objects) for information on how to tranform these IDs to actual objects.


** Example **

Query all customers and include a list of tickets and contacts of each customer.

``` bash
.../customers?include=Tickets,Contacts
```