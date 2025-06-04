# Clash of Clans API

To communicate with Clash API you must create and account with them [Clash API](https://developer.clashofclans.com/#/) and then create a key, use the token from the created key and use it under the env variable `CLASH_API_TOKEN` also add `CLASH_API_BASE_URL` the default value is `https://api.clashofclans.com/v1`.

For now, is unknown how to reauthenticate and rate limit of the Clash API.

iClash will make request to their API and store the relevant data as follow:

![iclash-data-fetching](/docs/iclash_data_fetching.drawio.png "Iclash Data Fetching")
