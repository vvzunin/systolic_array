#pragma once
#include <boost/asio.hpp>
#include <chrono>
#include <concepts>

using namespace boost;

class Serial
{
public:
    Serial(asio::io_context &io, std::string &device, int baudrate);

    system::error_code open() noexcept;
    system::error_code close() noexcept;
    bool is_open() noexcept;

    template<std::integral T>
    size_t write(const std::vector<T> &buffer, system::error_code &ec) noexcept;

    template<std::integral T>
    size_t read(std::vector<T> &buffer, system::error_code &ec, std::chrono::milliseconds timeout) noexcept;

    void set_device(const std::string &device_name) noexcept;

    ~Serial();
private:
    void setup();
    asio::serial_port port;
    asio::io_context& io;
    std::string device;
    int baudrate;
};

template <std::integral T>
size_t Serial::write(const std::vector<T> &buffer, system::error_code &ec) noexcept
{
    auto asio_buffer = asio::buffer(buffer);
    size_t bytes = boost::asio::write(port, asio_buffer, ec);
    return bytes;
}

template <std::integral T>
size_t Serial::read(std::vector<T> &buffer, system::error_code &ec, std::chrono::milliseconds timeout) noexcept
{

    auto asio_buffer = asio::buffer(buffer);
    size_t bytes;
    asio::async_read(port, asio_buffer, asio::cancel_after(timeout, 
                     [&ec, &bytes](const boost::system::error_code &rec, std::size_t rbytes) { bytes = rbytes; ec = rec; }));
    io.run();
    return bytes;
}