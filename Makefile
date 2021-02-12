.ONESHELL:

SHELL := /bin/bash
DATE_ID := $(shell date +"%y.%m.%d")
# Get package name from pwd
PACKAGE_NAME := $(shell basename $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
.DEFAULT_GOAL := help

# UPDATE SOME OF THESE VAR
USER_DIR = $(USER)/$(shell basename $(CURDIR))
DOCKER_IMAGE  = $(shell echo $(USER_DIR) | tr '[:upper:]' '[:lower:]')

MAIN_FILE = main.py
DOCKERFILE_DIR = deployment/docker
KUBERNETES_DIR = deployment/kubernetes
DOCS_DIR = docs/src


define BROWSER_PYSCRIPT
import os, webbrowser, sys

try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef

define PRINT_HELP_PYSCRIPT
import re, sys

class Style:
    BOLD = '\033[1m'
    GREEN = '\033[32m'
    RED = '\033[31m'
    ENDC = '\033[0m'

print(f"{Style.BOLD}Please use `make <target>` where <target> is one of{Style.ENDC}")
for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if line.startswith("# -------"):
		print(f"\n{Style.RED}{line}{Style.ENDC}")
	if match:
		target, help_msg = match.groups()
		if not target.startswith('--'):
			print(f"{Style.BOLD+Style.GREEN}{target:20}{Style.ENDC} - {help_msg}")
endef

export BROWSER_PYSCRIPT
export PRINT_HELP_PYSCRIPT
# See: https://docs.python.org/3/using/cmdline.html#envvar-PYTHONWARNINGS
export PYTHONWARNINGS=ignore
BROWSER := $(PYTHON) -c "$$BROWSER_PYSCRIPT"


# If you want a specific Python interpreter define it as an envvar
# $ export PYTHON_ENV=
ifdef PYTHON_ENV
	PYTHON := $(PYTHON_ENV)
else
	PYTHON := python3
endif

#################################### Functions ###########################################
# Function to check if package is installed else install it.
define install_pip_pkg_if_not_exist
	@for pkg in ${1} ${2} ${3}; do \
		if ! command -v "$${pkg}" >/dev/null 2>&1; then \
			echo "installing $${pkg}"; \
			$(PYTHON) -m pip install $${pkg}; \
		fi;\
	done
endef

define install_docker_pkg
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Installing Docker."
		bash -c "curl -fsSL https://get.docker.com | sudo"; \
	fi
endef


define install-kubectl
	if ! command -v kubectl >/dev/null 2>&1; then \
		if [ "$$(uname)" == "Darwin" ]; then \
			brew install kubectl; \
		elif [ "$$(expr substr $$(uname -s) 1 5)" == "Linux" ]; then \
			sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl; \
			curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -; \
			echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list; \
			sudo apt-get update; \
			sudo apt-get install -y kubectl; \
		fi; \
	fi
endef


# Function to create python virtualenv if it doesn't exist
define create-venv
	$(call install_pip_pkg_if_not_exist,virtualenv)

	@if [ ! -d ".$(PACKAGE_NAME)_venv" ]; then \
		$(PYTHON) -m virtualenv ".$(PACKAGE_NAME)_venv" -p $(PYTHON) -q; \
		.$(PACKAGE_NAME)_venv/bin/python -m pip install -U pip; \
		echo "\".$(PACKAGE_NAME)_venv\": Created successfully!"; \
	fi;
	@echo "Source virtual environment before tinkering"
	@echo "Manually run: \`source .$(PACKAGE_NAME)_venv/bin/activate\`"
endef

define add-gitignore
	PKGS=venv,python,JupyterNotebooks,SublimeText,VisualStudioCode,vagrant
	curl -sL https://www.gitignore.io/api/$${PKGS} > .gitignore
endef

define check-current-os
	if [ "$$(uname)" == "Darwin" ]; then \
		echo "Please follow instructions on how to install docker on mac"; \
		echo "Click: https://docs.docker.com/docker-for-mac/install/"; \
		exit 1; \
	elif [ "$$(expr substr $$(uname -s) 1 5)" == "Linux" ]; then \
		echo "Note: You might need to ensure you have sudo privileges, before you continue."; \
	fi;
endef
########################################### END ##########################################

help:
	@$(PYTHON) -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

# ------------------------------------ Boilerplate Code ----------------------------------

boilerplate:  ## Add simple 'README.md' and .gitignore
	@echo "# $(PACKAGE_NAME)" | sed 's/_/ /g' >> README.md
	@$(call add-gitignore)

# ------------------------------------ Installations -------------------------------------

dev_venv: venv ## Install the package in development mode including all dependencies inside a virtualenv (container).
	@$(PYTHON_VENV) -m pip install .[dev];
	echo -e "\n--------------------------------------------------------------------"
	echo -e "Usage:\nPlease run:\n\tsource .$(PACKAGE_NAME)_venv/bin/activate;"
	echo -e "\t$(PYTHON) -m pip install .[dev];"
	echo -e "Start developing..."

--check_os:
	$(call check-current-os)

.SILENT: --check_os install_docker
install_docker: --check_os  ## Check if docker and docker-compose exists, if not install them on host
	$(call install_docker_pkg)
	$(call install_pip_pkg_if_not_exist,docker-compose)

install:  ## Check if package exist, if not install the package
# 	@$(PYTHON) -c "import $(PACKAGE_NAME)" >/dev/null 2>&1 ||
	$(PYTHON) -m pip install .;

venv:  ## Create virtualenv environment on local directory.
	@$(create-venv)

# ------------------------------------ Builds  -------------------------------------------

# You can easily chain a number of targets
bootstrap: clean install-hooks dev docs  ## Installs development packages, hooks and generate docs for development

.SILENT: lint_docker_image build_docker_image
build_docker_image: lint_docker_image  ## Build docker image from local Dockerfile.
	docker build -f $(DOCKERFILE_DIR)/Dockerfile -t $(DOCKER_IMAGE) .
	touch .$@

tag_docker_image: lint_docker_image  ## Tag a container before pushing to cam registry.
	if [ ! -f ".build_${DOCKER_IMAGE}" ]; then \
		echo "Rebuilding the image: ${DOCKER_IMAGE}"; \
		make build_docker_image; \
	fi;
	docker tag "$(DOCKER_IMAGE):latest" "$(DOCKER_IMAGE):latest"

push_docker_image: tag_docker_image  ## Push tagged container to cam registry.
	docker push $(DOCKER_IMAGE):latest
	rm -rf ".build_docker_image"

# ------------------------------------Code Style  ----------------------------------------
lint_docker_image:  ## Run Dockerfile linter (https://github.com/hadolint/hadolint)
	$(call install_docker_pkg)
	@docker run --rm -i hadolint/hadolint < $(DOCKERFILE_DIR)/Dockerfile

lint:  ## Check style with `flake8` and `mypy`
	$(call install_pip_pkg_if_not_exist,flake8)
	@$(PYTHON) -m flake8 --max-line-length 90 $(PACKAGE_NAME)
	# find . -name "*.py" | xargs pre-commit run -c .configs/.pre-commit-config.yaml flake8 --files
	# @$(PYTHON) -m mypy
	# @yamllint .

checkmake:  ## Check Makefile style with `checkmake`
	$(call install_docker_pkg)
	docker run --rm -v $(CURDIR):/data cytopia/checkmake Makefile

formatter:  ## Format style with `black` and sort imports with `isort`
	$(call install_pip_pkg_if_not_exist,black,isort)
	@isort -m 3 -tc -rc .
	@black -l 90 .
# 	find . -name "*.py" | xargs pre-commit run -c .configs/.pre-commit-config.yaml isort --files

#  ---------------------------------- Git Hooks ------------------------------------------

install_hooks:  ## Install `pre-commit-hooks` on local directory [see: https://pre-commit.com]
	$(call install_pip_pkg_if_not_exist,pre-commit)
	pre-commit install --install-hooks -c .configs/.pre-commit-config.yaml

pre_commit:  ## Run `pre-commit` on all files
	$(call install_pip_pkg_if_not_exist,pre-commit)
	pre-commit run --all-files -c .configs/.pre-commit-config.yaml

# ------------------------------------ Python Packaging ----------------------------------

dist: clean ## Builds source and wheel package
	$(PYTHON) setup.py sdist
	$(PYTHON) setup.py bdist_wheel
	ls -l dist

# ------------------------------------ Project Execution ---------------------------------

run_in_docker:  ## Run python app in a docker container
	$(call install_docker_pkg)
	docker run --rm -ti --volume "$(CURDIR)":/app $(DOCKER_IMAGE) \
	bash -c "$(PYTHON) $(MAIN_FILE)"

get_container_logs:  ## Get logs of running container
	$(call install_docker_pkg)
	docker logs -f $$(docker ps | grep $(DOCKER_IMAGE) | tr " " "\n" | tail -1)

run:  ## Run Python app
	$(PYTHON) $(MAIN_FILE)

# ------------------------------------ Deployment ----------------------------------------
.SILENT: --check_os deploy_app
deploy_app: --check_os ## Deploy App with Kubernetes manifests
	$(call install-kubectl)
	kubectl apply -f $(KUBERNETES_DIR)

pod_logs:  ## Get logs from all running pods on a defined namespace
	@if [ ! ${pod_namespace} ]; then \
		echo "Usage:"; \
		echo "$(MAKE) $@ pod_namespace=\"<namespace>\""; \
	else \
		for POD in $$(kubectl get pods -n ${pod_namespace} | cut -f 1 -d ' ' | grep ^[a-z]); do \
			echo '----------------------------------------'; \
			echo "-------- logs for $${POD} ---------------"; \
			echo '----------------------------------------'; \
			kubectl logs -n ${pod_namespace} $${POD}; \
		done; \
	fi;

port_forward:  ## Forward local ports to a pod in a namespace
	@if [ ! ${pod_namespace} ]; then \
		echo "Usage:"; \
		echo "$(MAKE) $@ pod_namespace=\"<namespace>\" ports=4111:3111"; \
	else \
		kubectl port-forward -n ${pod_namespace} $$(kubectl get pods -n ${pod_namespace} | cut -f 1 -d ' ' | grep ^[a-z]) ${ports}; \
	fi

pods_status:  ## Check running pods on sandbox namespace
	@if [ ! ${pod_namespace} ]; then \
		echo "Usage:"; \
		echo "$(MAKE) $@ pod_namespace=\"<namespace>\""; \
	else \
		kubectl get pods -o wide -n ${pod_namespace}; \
	fi

pods_services:  ## Check all running services on pods on sandbox namespace
	@if [ ! ${pod_namespace} ]; then \
		echo "Usage:"; \
		echo "$(MAKE) $@ pod_namespace=\"<namespace>\""; \
	else \
		kubectl get svc -o wide -n ${pod_namespace}; \
	fi

# ------------------------------------Clean Up  ------------------------------------------
.PHONY: clean
clean: clean_build clean_docs clean_pyc clean_test clean_docker ## Remove all build, test, coverage and Python artefacts

clean_build:  ## Remove build artefacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -fr {} +
	find . -name '*.xml' -exec rm -fr {} +

clean_docs:  ## Remove docs/_build artefacts, except PDF and singlehtml
	# Do not delete <module>.pdf and singlehtml files ever, but can be overwritten.
	find docs/compiled_docs ! -name "$(PACKAGE_NAME).pdf" ! -name 'index.html' -type f -exec rm -rf {} +
	rm -rf docs/compiled_docs/doctrees
	rm -rf docs/compiled_docs/html
	rm -rf $(DOCS_DIR)/modules.rst
	rm -rf $(DOCS_DIR)/$(PACKAGE_NAME)*.rst
	rm -rf $(DOCS_DIR)/README.md

clean_pyc:  ## Remove Python file artefacts
	find . -name '*.pyc' -exec rm -rf {} +
	find . -name '*.pyo' -exec rm -rf {} +
	find . -name '*~' -exec rm -rf {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean_test:  ## Remove test and coverage artefacts
	rm -fr .$(PACKAGE_NAME)_venv
	rm -fr .tox/
	rm -fr .pytest_cache
	rm -fr .mypy_cache
	rm -fr .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache

clean_docker:  ## Remove docker image
	if docker images | grep $(DOCKER_IMAGE); then \
	 	docker rmi $(DOCKER_IMAGE) || true;\
	fi;

# ------------------------------------ Tests ---------------------------------------------

test:  ## Run tests quickly
	$(call install_pip_pkg_if_not_exist,pytest,nose)
	$(PYTHON) -m pytest -sv
# 	$(PYTHON) -m nose -sv

# ------------------------------------ Test Coverage --------------------------------------

coverage:  ## Check code coverage quickly with pytest
	$(call install_pip_pkg_if_not_exist,coverage)
	coverage run --source=$(PACKAGE_NAME) -m pytest -s .
	coverage xml
	coverage report -m
	coverage html

coveralls:  ## Upload coverage report to coveralls.io
	$(call install_pip_pkg_if_not_exist,coveralls)
	coveralls --coveralls_yaml .coveralls.yml || true

view_coverage:  ## View code coverage
	$(BROWSER) htmlcov/index.html

# ------------------------------------ Changelog Generation ----------------------

changelog:  ## Generate changelog for current repo
	docker run -it --rm -v "$(CURDIR)":/usr/local/src/your-app mmphego/git-changelog-generator

# ------------------------------------ Documentation Generation ----------------------

.PHONY: --docs_depencencies
--docs_depencencies:  ## Check if sphinx is installed, then generate Sphinx HTML documentation dependencies.
	$(call install_pip_pkg_if_not_exist,sphinx-apidoc)
	sphinx-apidoc -o $(DOCS_DIR) $(PACKAGE_NAME)
	sphinx-autogen $(DOCS_DIR)/*.rst


complete_docs: --docs_depencencies ## Generate a complete Sphinx HTML documentation, including API docs.
	$(MAKE) -C $(DOCS_DIR) html
	@echo "\n\nNote: Documentation located at: ";
	@echo "${PWD}/docs/compiled_docs/html/index.html";

docs: --docs_depencencies ## Generate a single Sphinx HTML documentation, with limited API docs.
	$(MAKE) -C $(DOCS_DIR) singlehtml;
	mv docs/compiled_docs/singlehtml/index.html docs/compiled_docs/;
	rm -rf docs/compiled_docs/singlehtml;
	rm -rf docs/compiled_docs/doctrees;
	echo "\n\nNote: Documentation located at: ";
	echo "${PWD}/docs/compiled_docs/index.html";

pdf_doc: --docs_depencencies ## Generate a Sphinx PDF documentation, with limited including API docs. (Optional)
	@if command -v latexmk >/dev/null 2>&1; then \
		$(MAKE) -C $(DOCS_DIR) latex; \
		if [ -d "docs/compiled_docs/latex" ]; then \
			$(MAKE) -C docs/compiled_docs/latex all-pdf LATEXMKOPTS=-quiet; \
			mv docs/compiled_docs/latex/$(PACKAGE_NAME).pdf docs; \
			rm -rf docs/compiled_docs/latex; \
			rm -rf docs/compiled_docs/doctrees; \
		fi; \
		echo "\n\nNote: Documentation located at: "; \
		echo "${PWD}/docs/$(PACKAGE_NAME).pdf"; \
	else \
		@echo "Note: Untested on WSL/MAC"; \
		@echo "  Please install the following packages in order to generate a PDF documentation.\n"; \
		@echo "  On Debian run:"; \
		@echo "    sudo apt install texlive-latex-recommended texlive-fonts-recommended texlive-latex-extra latexmk"; \
	fi
