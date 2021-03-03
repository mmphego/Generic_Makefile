# Generic Makefile
An over-engineered `Makefile` template for my Python projects.

## Download

Run `curl -fsSL https://git.io/get-makefile > Makefile` from your root directory
or add `get_makefile` alias into your `,bashrc`:
- `echo "alias get_makefile='curl -fsSL https://git.io/get-makefile > ./Makefile'" | tee -a ~/.bashrc'
- `source ~/.bashrc` 

## Usage

Make changes where needed!

```bash
Please use `make <target>` where <target> is one of

# ------------------------------------ Boilerplate Code ----------------------------------

boilerplate          - Add simple 'README.md' and .gitignore

# ------------------------------------ Version Control -----------------------------------

git_init_repo        - Create a new git repository and add boilerplate code.

# ------------------------------------ Installations -------------------------------------

dev_venv             - Install the package in development mode including all dependencies inside a virtualenv (container).
install_docker       - Check if docker and docker-compose exists, if not install them on host
install              - Check if package exist, if not install the package
venv                 - Create virtualenv environment on local directory.

# ------------------------------------ Builds  -------------------------------------------

bootstrap            - Installs development packages, hooks and generate docs for development
build_docker_image   - Build docker image from local Dockerfile.
tag_docker_image     - Tag a container before pushing to cam registry.
push_docker_image    - Push tagged container to cam registry.

# ------------------------------------Code Style  ----------------------------------------

lint_docker_image    - Run Dockerfile linter (https://github.com/hadolint/hadolint)
lint                 - Check style with `flake8` and `mypy`
checkmake            - Check Makefile style with `checkmake`
formatter            - Format style with `black` and sort imports with `isort`
install_hooks        - Install `pre-commit-hooks` on local directory [see: https://pre-commit.com]
pre_commit           - Run `pre-commit` on all files

# ------------------------------------ Python Packaging ----------------------------------

dist                 - Builds source and wheel package

# ------------------------------------ Project Execution ---------------------------------

run_in_docker        - Run python app in a docker container
get_container_logs   - Get logs of running container
run                  - Run Python app

# ------------------------------------ Deployment ----------------------------------------

deploy_app           - Deploy App with Kubernetes manifests
pod_logs             - Get logs from all running pods on a defined namespace
port_forward         - Forward local ports to a pod in a namespace
pods_status          - Check running pods on sandbox namespace
pods_services        - Check all running services on pods on sandbox namespace

# ------------------------------------Clean Up  ------------------------------------------

clean                - Remove all build, test, coverage and Python artefacts
clean_build          - Remove build artefacts
clean_docs           - Remove docs/_build artefacts, except PDF and singlehtml
clean_pyc            - Remove Python file artefacts
clean_test           - Remove test and coverage artefacts
clean_docker         - Remove docker image

# ------------------------------------ Tests ---------------------------------------------

test                 - Run tests quickly

# ------------------------------------ Test Coverage --------------------------------------

coverage             - Check code coverage quickly with pytest
coveralls            - Upload coverage report to coveralls.io
view_coverage        - View code coverage

# ------------------------------------ Changelog Generation ----------------------

changelog            - Generate changelog for current repo

# ------------------------------------ Documentation Generation ----------------------

complete_docs        - Generate a complete Sphinx HTML documentation, including API docs.
docs                 - Generate a single Sphinx HTML documentation, with limited API docs.
pdf_doc              - Generate a Sphinx PDF documentation, with limited including API docs. (Optional)
```
