BUILD_DIR = out
APP = interpolation_app

build:
	@mix deps.get
	@mix escript.build
run: build
	cat data/line.csv | ./$(BUILD_DIR)/$(APP) --linear --step 0.7
	# @./$(BUILD_DIR)/$(APP)
run-linear:
	./$(BUILD_DIR)/$(APP) --linear --step 0.7 < data/example.csv

run-newton: build
	./$(BUILD_DIR)/$(APP) --newton -n 4 --step 0.5 < data/example.csv

run-lagrange: build
	./$(BUILD_DIR)/$(APP) --lagrange -n 4 --step 0.5 < data/example.csv

run-gauss: build
	./$(BUILD_DIR)/$(APP) --gauss -n 5 --step 0.5 < data/example.csv

fmt:
	mix format

clean: 
	rm $(BUILD_DIR)/$(APP)
	mix clean
