# Tests

This directory contains all test projects and test-related resources.

## Unit

This directory contains unit tests for the Orders.csproj. It utilizes [XUnit](https://xunit.net/?tabs=cs), as I remember this being my personaly preferred testing tool.

> Not because XUnit is "better" than NUnit. It's not. I just like it more than for no other reason than "because".  

## BlackBox

This directory contains tests that test the system, as from a consumer's perspective. No references are made to the [Orders.csproj](../Orders/Orders.csproj), relying only on the generated OpenAPI documentation. XUnit is still used as the testing tool.
