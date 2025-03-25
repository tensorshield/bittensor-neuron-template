include config.mk
app.name ?= $(error Set app.name in config.mk)
PYTHON ?= python
PYTHON_VERSION ?= 3.11
PIP_CACHE_DIR ?= $(CURDIR)/.cache/pip
export
app.srcdir = $(CURDIR)/$(app.name)
docker ?= docker
docker.build.args ?=
docker.build.name ?= $(app.name)
docker.build.tag ?= latest
docker.build.targets ?= miner validator cli
ifdef docker.build.target
docker.build.tag := $(docker.build.tag)-$(docker.build.target)
endif
docker.build.qualname ?= $(docker.build.name):$(docker.build.tag)
ifdef docker.registry.name
ifdef docker.repository.name
docker.registry.image ?= $(docker.registry.name)/$(docker.repository.name)
endif
endif
git = git
python = $(PYTHON)$(PYTHON_VERSION)
python.envdir = $(CURDIR)/env
python.devlibdir = $(CURDIR)/.lib
python.devrun = $(python.watchdog) auto-restart -R -d $(CURDIR)/bin -d $(app.srcdir) --signal SIGKILL -- $(python.envdir)/bin/python
python.pip = $(python.envdir)/bin/pip
python.pip.devinstall = $(python.devlibdir)/bin/python -m pip install
python.test.dependencies = pytest pytest_asyncio coverage watchdog
python.watchdog = $(python.devlibdir)/bin/watchmedo
ifneq ($(wildcard $(python.envdir)/bin/python),)
python = $(python.envdir)/bin/python
endif
ifeq ($(@), .template)
PATH := $(PATH):$(python.devlibdir)/bin
PYTHONPATH := $(python.devlibdir)
else
PYTHONPATH := $(CURDIR)
endif
template.dockerfile 				= Dockerfile.tensorshield.j2
template.bin.entrypoint.py 			= bin/entrypoint.py.tensorshield.j2
template.main.app.cli.__init__.py 	= templates.tensorshield.j2/main/app/cli/__init__.py.j2
template.main.app.cli._app.py 		= templates.tensorshield.j2/main/app/cli/_app.py.j2
template.main.app.cli._run.py 		= templates.tensorshield.j2/main/app/cli/_run.py.j2
template.main.app.miner.py 			= templates.tensorshield.j2/main/app/miner.py.j2
template.main.app.validator.py 		= templates.tensorshield.j2/main/app/validator.py.j2

VARDIR := $(CURDIR)/var
export


env: $(python.devlibdir)
	@$(python) -m venv $(python.envdir)
	@$(python.pip) install -r requirements.txt


all: env
all: bin
all: bin/$(app.name)
all: Dockerfile
all: $(app.name)
all: tests/smoke
all: tests/unit
all: tests/integration
all: tests/system
all:
	@find . -name '*.tensorshield.j2' -delete
	@rm -rf templates.tensorshield.j2
	@git add -A


runminer: var
	@$(python.devrun) $(CURDIR)/bin/$(app.name) run miner


runvalidator: var
	@$() run validator


bin:
	@mkdir -p $(CURDIR)/bin


bin/$(app.name):
	@$(python.devlibdir)/bin/jinja2 $(template.bin.entrypoint.py)\
		-D app_name=$(app.name)\
		> bin/$(app.name)
	@chmod +x bin/$(app.name)
	@git add bin/$(app.name)


clean:
	@$(git) clean -fdx


var:
	@mkdir -p $(VARDIR)


Dockerfile:
	@$(python.devlibdir)/bin/jinja2 $(template.dockerfile)\
		-D app_name=$(app.name)\
		-D docker_base_image=$(docker.base_image)\
		> Dockerfile
	@git add -f Dockerfile

$(app.name):
	@$(MAKE) .directory dirname=$(@)
	@$(MAKE) .directory dirname=$(@)/app/cli
	@$(MAKE) .directory dirname=$(@)/canon/models
	@$(MAKE) .directory dirname=$(@)/infra
	@$(MAKE) .directory dirname=$(@)/lib
	@$(MAKE) .template template=$(template.main.app.cli._app.py)\
		dst=$(app.name)/app/cli/_app.py
	@$(MAKE) .template template=$(template.main.app.cli.__init__.py)\
		dst=$(app.name)/app/cli/__init__.py
	@$(MAKE) .template template=$(template.main.app.miner.py)\
		dst=$(app.name)/app/miner.py
	@$(MAKE) .template template=$(template.main.app.validator.py)\
		dst=$(app.name)/app/validator.py
	@$(MAKE) .template template=$(template.main.app.cli._run.py)\
		dst=$(app.name)/app/cli/_run.py
	@git add $(app.name)
	@ln -s bin/$(app.name) $(python.envdir)/bin/


tests/%:
	@$(MAKE) .directory dirname=$(@)
	@touch $(@)/.gitkeep


$(python.devlibdir):
	@$(PYTHON)$(PYTHON_VERSION) -m venv $(python.devlibdir)
	@$(python.devlibdir)/bin/python -m pip install jinja2-cli
	@$(foreach dep,$(python.test.dependencies), $(python.pip.devinstall) $(dep);)


.directory:
	@mkdir -p $(dirname)
	@git add $(dirname)


.template:
	@$(python.devlibdir)/bin/jinja2 $(template) -D app_name=$(app.name) > $(dst)


docker-build:
	@$(docker) build -t $(docker.build.qualname) .\
		$(foreach arg, $(docker.build.args), --build-arg $(arg))
ifdef  docker.registry.image
	@$(docker) tag $(docker.build.qualname) $(docker.registry.image)/$(docker.build.qualname)
endif


docker-targets:
	@$(foreach target,$(docker.build.targets), $(MAKE) docker-build docker.build.target=$(target) docker.build.tag=$(docker.build.tag)-$(target);)


ifdef docker.registry.image
docker-push: docker-targets
	$(foreach target,$(docker.build.targets), $(docker) push $(docker.registry.image)/$(app.name):$(docker.build.tag)-$(target);)
endif
