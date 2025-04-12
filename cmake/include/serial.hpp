#pragma once
#include <boost/asio.hpp>
#include <concepts>

using namespace boost;

class Serial
{
public:
    Serial(asio::io_context &io, std::string &device, int baudrate);

    system::error_code open() noexcept;
    system::error_code close() noexcept;
    bool is_open() noexcept;

    system::error_code write(const std::string &buffer) noexcept;
    template<std::integral T>
    system::error_code write(const std::vector<T> &buffer) noexcept;

    system::error_code read(std::string &buffer, size_t exact_size) noexcept;
    template<std::integral T>
    system::error_code read(std::vector<T> &buffer, size_t exact_size) noexcept;

    template<std::integral T>
    system::error_code send_packet(uint8_t cmd, std::vector<std::vector<T>> data = {}); 

    void set_device(const std::string &device_name) noexcept;

    ~Serial();
private:
    void setup();
    asio::serial_port port;
    std::string device;
    int baudrate;
};

template <std::integral T>
system::error_code Serial::write(const std::vector<T> &buffer) noexcept
{
    system::error_code ec;
    boost::asio::write(port, asio::buffer(buffer), ec);
    return ec;
}
template <std::integral T>
system::error_code Serial::read(std::vector<T> &buffer, size_t exact_size) noexcept
{
    system::error_code ec;
    boost::asio::read(port, asio::buffer(buffer), ec);
    return ec;
}

template<std::integral T>
system::error_code Serial::send_packet(uint8_t cmd, std::vector<std::vector<T>> data)
{
    system::error_code ec;
    std::vector<uint8_t> control_sequence = {0x55, cmd};
    if(!data.empty()) {
        for(auto& row : data) { 
            for(auto& el : row) {
                ec = write<uint8_t>(control_sequence);
                if(ec) return ec;
                std::vector<T> buf = {el};
                ec = write<T>(buf);
                if(ec) return ec;
            }
        }
    }
    else {
        write<uint8_t>(control_sequence);
    }
    return ec;
}