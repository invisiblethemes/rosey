# Rosey 🤖

Rosey the theme deploy bot

Used to deploy themes to QA stores via GitHub Actions

## Updating Dockerfile.base

If you update the base Dockerfile you'll have to do the following:
1. Run `docker login` with an account that has access to the invisiblethemes Docker Hub account
1. Run `make push` to build the docker image and push it to Docker Hub.

TODO: automate this with a GH Action for Rosey itself
