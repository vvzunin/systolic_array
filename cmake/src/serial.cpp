#include "serial.hpp"

Serial::Serial(asio::io_context &io, std::string &device_name, int baud)
    : port {io}, device {device_name}, baudrate {baud}
{
    
}

system::error_code Serial::open() noexcept
{
    system::error_code ec;
    port.open(device, ec);
    if(!ec) setup();
    return ec;
}

bool Serial::is_open() noexcept
{
    return port.is_open();
}

system::error_code Serial::close() noexcept
{
    system::error_code ec;
    port.close(ec);
    return ec;
}

system::error_code Serial::write(const std::string &buffer) noexcept
{
    system::error_code ec;
    boost::asio::write(port, asio::buffer(buffer), ec);
    return ec;
}

system::error_code Serial::read(std::string &buffer, size_t exact_size) noexcept
{
    auto asio_buf = asio::dynamic_string_buffer(buffer, exact_size);
    system::error_code ec;
    boost::asio::read(port, asio_buf, ec);
    return ec;
}

void Serial::set_device(const std::string &device_name) noexcept
{
    device = device_name;
}

Serial::~Serial()
{
    if(port.is_open()) port.close();
}

void Serial::setup()
{
    using namespace asio;
    port.set_option(serial_port_base::baud_rate(baudrate));
    port.set_option(serial_port_base::character_size(8));
    port.set_option(serial_port_base::parity(serial_port_base::parity::none));
    port.set_option(serial_port_base::stop_bits(serial_port_base::stop_bits::one));
}
