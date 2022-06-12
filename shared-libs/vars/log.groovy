#!/usr/bin/env groovy

def info(message) {
  COLOR_INFO="\033[1;36m"
  COLOR_RESET="\033[0m"
  echo "${COLOR_INFO}INFO: ${message}${COLOR_RESET}"
}

def warning(message) {
  COLOR_WARN="\033[1;93m"
  COLOR_RESET="\033[0m"
  echo "${COLOR_WARN}WARNING: ${message}${COLOR_RESET}"
}

def error(message) {
  COLOR_ERROR="\033[1;31m"
  COLOR_RESET="\033[0m"
  echo "${COLOR_ERROR}ERROR: ${message}${COLOR_RESET}"
}

def pass(message) {
  COLOR_PASS="\033[1;32m"
  COLOR_RESET="\033[0m"
  echo "${COLOR_PASS}PASS: ${message}${COLOR_RESET}"
}