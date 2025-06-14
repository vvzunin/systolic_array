#include <cstdint>
#include <chrono>

using namespace std::chrono_literals;

#define START_BYTE static_cast<uint8_t>(0x55)
#define STOP_BYTE static_cast<uint8_t>(0x00)
#define CMD_DATA static_cast<uint8_t>(0x01)
#define CMD_FETCH_WEIGHTS static_cast<uint8_t>(0x02)
#define CMD_LOAD_WEIGHTS static_cast<uint8_t>(0x03)
#define CMD_FETCH_DATA static_cast<uint8_t>(0x04)
#define CMD_START_COMP static_cast<uint8_t>(0x05)

#define BAUDRATE 9600
#define UART_TIMEOUT 1000ms

#define COLOR_ERROR ImVec4{255, 0, 0, 255}
#define COLOR_OK ImVec4{0, 255, 0, 255}
#define COLOR_WARN ImVec4{255, 255, 0, 255}

#define LOG_CATEGORY_UART "uart"
#define LOG_CATEGORY_CSV "csv"