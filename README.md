# Patron Passport plugin for Koha

This plugin allows separate instances of Koha to automatically import patrons from other Koha servers.
If a cardnumber is not found in an instances database, that server will query the other servers in the group
to find the server that has that patron, and will close the patron from it.

## Installation

This plugin requires data to be added to koha-conf.xml in the following format:
```xml
 <patron_passport>
    <servers>
        <server name="ServerB" address="libB.libraries.org" username="koha" password="koha" />
        <server name="ServerC" address="libC.libraries.org" username="koha" password="koha" />
    </servers>
 </patron_passport>
```
this must be inside the `config` block of the koha conf.