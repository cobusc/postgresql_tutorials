VENV=./venv
PYTHON=python3

virtualenv: $(VENV)
	$(VENV)/bin/pip install pip --upgrade
	$(VENV)/bin/python setup.py develop

$(VENV):
	virtualenv --python=$(PYTHON) $(VENV)
