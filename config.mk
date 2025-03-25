PYTHON_VERSION ?= 3.11
app.name ?= $(error Set app.name in config.mk)
docker.base_image ?= python:3.11-alpine