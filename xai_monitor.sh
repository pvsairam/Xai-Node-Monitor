#!/bin/bash

##########################################################################
## FOLLOW ME ON TWITTER IF YOU FIND THIS USEFUL
## @xtestnet
## https://twitter.com/xtestnet
##########################################################################

## UPDATE TELEGRAM

TELEGRAM_TOKEN="" # example 123456789:jbd78sadvbdy63d37gda37bd8
TELEGRAM_CHAT_ID="" # example -1234567890

## Test telegram integration by calling
## ./xai_monitor.sh --test-telegram

##########################################################################

# Configuration
LOG_FILE="screenlog.0" # Log file generated by screen -L -r xai
MAX_LOG_SIZE=500000 # Maximum log file size in bytes (e.g., 50 KB)

#ERROR_PATTERN="Submitting assertion" # Replace with the specific error pattern you're looking for
ERROR_PATTERNS=("Submitting assertion" "Challenge listener stopped") # Array of error patterns


CHECK_INTERVAL=60 # Time in seconds to check if the process is running (60  = 1 minute)
start_command="./sentry-node-cli-linux"

CONFIG_FILE="telegram_config.sh"
SCREEN_SESSION_NAME="monitor"


# Resume or create a new screen session named "monitor"
# screen -d -R "$SCREEN_SESSION_NAME"

# Function to send a message to Telegram
send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$message"
}

# Function for testing Telegram message
test_telegram_message() {
    echo "Sending test message to Telegram..."
    send_telegram_message "This is a test message from the script."
    echo "Test message sent."
}

# Function to load or request Telegram configuration
load_or_request_telegram_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        local masked_telegram_id="${TELEGRAM_TOKEN:0:10}"
        masked_telegram_id=$(printf '%*s' "${#masked_telegram_id}" | tr ' ' '*')
        masked_telegram_id="$masked_telegram_id${TELEGRAM_TOKEN:10}"

        echo "Loaded from config:"
        echo "Telegram Bot ID: $masked_telegram_id"
        echo "Telegram Chat ID: $TELEGRAM_CHAT_ID"
    fi

    while true; do
        if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
            read -p "Enter Telegram Bot ID: " TELEGRAM_TOKEN
            read -p "Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
            echo "You entered:"
            echo "Telegram Bot ID: $TELEGRAM_TOKEN"
            echo "Telegram Chat ID: $TELEGRAM_CHAT_ID"
            read -p "Are these values correct? (Y/n): " confirmation
            if [[ -z $confirmation || $confirmation == [Yy] ]]; then
                echo "TELEGRAM_TOKEN='$TELEGRAM_TOKEN'" > "$CONFIG_FILE"
                echo "TELEGRAM_CHAT_ID='$TELEGRAM_CHAT_ID'" >> "$CONFIG_FILE"
                read -p "Would you like to test the Telegram integration now? (y/N): " test_confirmation

                if [[ $test_confirmation == [Yy] ]]; then
                    test_telegram_message
                fi
                break
            fi
        else
            break
        fi
    done
}

# Load or request Telegram configuration
load_or_request_telegram_config


# Check if sentry-node-cli-linux exists in the current directory
if [ ! -f "./sentry-node-cli-linux" ]; then
    echo "Error: sentry-node-cli-linux not found in the current directory."
    exit 1
fi



# Function to check and truncate log file
truncate_log_file() {
    if [ "$1" == "true" ]; then
        > "$LOG_FILE"
    elif [ -f "$LOG_FILE" ]; then
        local filesize=$(stat -c%s "$LOG_FILE")
        if [ $filesize -ge $MAX_LOG_SIZE ]; then
            > "$LOG_FILE"
        fi
    fi
}

# Main script
if [[ "$1" == "--test-telegram" ]]; then
    test_telegram_message
    exit 0
fi

# Background process to check if the process is running
(
    last_notification=0

    while true; do
        current_time=$(date +%s) # Get current time in seconds since epoch
        if ! pgrep -f "$start_command" > /dev/null; then
            # Check if more than an hour has passed since the last notification
            if (( current_time - last_notification > 3600 )); then
                echo "The script is not running. Sending notification to Telegram..."
                send_telegram_message "The sentry-node-cli-linux script has stopped running."
                last_notification=$current_time # Update last notification time
            fi
        fi
        sleep $CHECK_INTERVAL # Wait for the specified interval before checking again
        echo "The script is running."
    done
) &
bg_process_pid=$!

# Function to clean up background process
cleanup() {
    kill $bg_process_pid 2>/dev/null
}

# Set trap to call cleanup function on script exit
trap cleanup EXIT

echo "Monitor script started. Press (ctrl + a +d) to exit."

# Monitor the log file
tail -Fn0 "$LOG_FILE" | \
while read line ; do
    for pattern in "${ERROR_PATTERNS[@]}"; do
        echo "$line" | grep -i "$pattern" &> /dev/null
        if [ $? = 0 ]; then
            echo "Error found: $line"
            send_telegram_message "Msg: $line"
            truncate_log_file true
            break
        fi
    done
    truncate_log_file false
done

##########################################################################
## FOLLOW ME ON TWITTER IF YOU FIND THIS USEFUL
## @xtestnet
## https://twitter.com/xtestnet
##########################################################################
