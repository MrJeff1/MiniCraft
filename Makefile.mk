# Define game name and output file
GAME_NAME = MiniCraft.love
BIN_DIR = bin
LOVE_VERSION = 11.5 # Specify a version - adjust if needed

# Detect OS
OS := $(shell uname -s)

# Define paths to potential downloaded executables
LOVE_LINUX_APPIMAGE = $(BIN_DIR)/love-$(LOVE_VERSION)-x86_64.AppImage
LOVE_MACOS_APP = $(BIN_DIR)/love-$(LOVE_VERSION).app
LOVE_MACOS_EXEC = $(LOVE_MACOS_APP)/Contents/MacOS/love

.PHONY: all install build run run-source clean

all: run # Default target runs the compiled game

install: $(BIN_DIR)
ifeq ($(OS),Linux)
	sudo chmod -R 777 worlds/
	@echo "Detected Linux. Downloading LÖVE2D $(LOVE_VERSION) AppImage..."
	@if [ ! -f $(LOVE_LINUX_APPIMAGE) ]; then \
		curl -L "https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-x86_64.AppImage" -o $(LOVE_LINUX_APPIMAGE); \
		chmod +x $(LOVE_LINUX_APPIMAGE); \
		echo "Downloaded and made executable: $(LOVE_LINUX_APPIMAGE)"; \
	else \
		echo "LÖVE2D AppImage already exists: $(LOVE_LINUX_APPIMAGE)"; \
	fi
else ifeq ($(OS),Darwin)
	@echo "Detected macOS. Downloading LÖVE2D $(LOVE_VERSION) zip..."
	@if [ ! -d $(LOVE_MACOS_APP) ]; then \
		curl -L "https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-macos.zip" -o $(BIN_DIR)/love-macos.zip; \
		unzip $(BIN_DIR)/love-macos.zip -d $(BIN_DIR); \
		rm $(BIN_DIR)/love-macos.zip; \
		echo "Downloaded and extracted: $(LOVE_MACOS_APP)"; \
	else \
		echo "LÖVE2D app bundle already exists: $(LOVE_MACOS_APP)"; \
	fi
else
	@echo "Unsupported OS ($(OS)). Please install LÖVE2D $(LOVE_VERSION) manually and ensure 'love' is in your PATH."
	@echo "Download from: https://love2d.org/"
	# We could exit here, but let's let it try using system 'love' in build/run
endif

# Create the bin directory if it doesn't exist
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

build: install $(GAME_NAME)

# Rule to create the .love file
$(GAME_NAME):
	@echo "Building $(GAME_NAME)..."
	# Determine the love2d command to use for compilation
ifeq ($(OS),Linux)
	$(LOVE_LINUX_APPIMAGE) --compile $(GAME_NAME) .
else ifeq ($(OS),Darwin)
	$(LOVE_MACOS_EXEC) --compile $(GAME_NAME) .
else
	# Fallback to system love for other OS
	love --compile $(GAME_NAME) .
endif
	@echo "Build complete: $(GAME_NAME)"

run: build
	@echo "Running $(GAME_NAME)..."
	# Determine the love2d command to use for running
ifeq ($(OS),Linux)
	$(LOVE_LINUX_APPIMAGE) $(GAME_NAME)
else ifeq ($(OS),Darwin)
	$(LOVE_MACOS_EXEC) $(GAME_NAME)
else
	# Fallback to system love for other OS
	love $(GAME_NAME)
endif

# Original run target (renamed)
run-source:
	@echo "Running source directory..."
	# Determine the love2d command to use for running source
ifeq ($(OS),Linux)
	$(LOVE_LINUX_APPIMAGE) .
else ifeq ($(OS),Darwin)
	$(LOVE_MACOS_EXEC) .
else
	# Fallback to system love for other OS
	love .
endif

clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(GAME_NAME)
	@rm -rf $(BIN_DIR) # Optional: remove downloaded love executable and bin dir
	@echo "Clean complete."