# Patron Passport plugin for Koha

This plugin allows separate instances of Koha to automatically import patrons from other Koha servers.
If a cardnumber is not found in an instances database, that server will query the other servers in the group
to find the server that has that patron, and will close the patron from it.

## Installation

* Enable RESTBasicAuth on all Koha instances

This plugin requires data to be added to koha-conf.xml in the following format:
```xml
 <patron_passport>
    <setting name="default_category_code" value="PT"/>
    <setting name="default_branchcode" value="MPL"/>
    <setting name="use_logged_in_branchcode" value="1"/> <!-- has precedence over default branchcode -->

    <servers>
        <server name="ServerB" address="libB.libraries.org" username="koha" password="koha" />
        <server name="ServerC" address="libC.libraries.org" username="koha" password="koha" />
    </servers>
 </patron_passport>
```
this must be inside the `config` block of the koha conf.

## Setup

It is important that all the possible branchcodes and category codes be set up in all Koha instances
unless you are using the settings to replace the external codes with your own internal ones.
Any attept to import a patron with a branchcode or category code that is not valid in your Koha
instance will fail.
