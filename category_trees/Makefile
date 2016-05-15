VENV_DIR=./venv

run: $(VENV_DIR)
	$(VENV_DIR)/bin/python category.py

$(VENV_DIR):
	virtualenv --no-site-packages $(VENV_DIR)
	$(VENV_DIR)/bin/pip install psycopg2

