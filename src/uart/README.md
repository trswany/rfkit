# UART

This is a tiny and very basic UART implementation. It is designed to be used
without a processor, so there is no AXI or other bus interface. It is
statically configured and supports only 8N1 data framing (1 start bit, 8 data
bits, no parity bits, and one stop bit). The bus idle state is high (logic 1).

## UART Receiver

The receiver uses 16x oversampling, which means that the sample clock runs at
16x the nominal UART bitrate.

The start-bit detector waits until it detects a falling edge (mark -> space)
transition. It then collects the next 8 samples and verifies that at least
4 of those samples are space (logic 0). If less than four samples are space,
the detector resets and starts looking for the next falling edge.
