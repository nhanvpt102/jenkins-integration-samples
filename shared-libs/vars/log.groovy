#!/usr/bin/env groovy

def info(message) {
  echo "[INFO] ${message}"
}

def warning(message) {
  echo "[WARNING] ${message}"
}

def error(message) {
  echo "[ERROR] ${message}"
}

def pass(message) {
  echo "[PASS] ${message}"
}