#include <stdio.h>
#include "xil_io.h"
#include "sleep.h"							// for usleep() function
#include <math.h>

// Test read:
//	Xil_Out32(0x43C00000, 0xCC);
//
// Test write:
//	int temp = 0;
//	temp = Xil_In32(0x43C00000);
//	printf("%i", temp);
//	printf("\n");


#define BASE_ADDR	 		0x43C00000
#define LED_REG_OFFSET 		0x00
#define DIR_REG_OFFSET		0x04
#define NON_REG_OFFSET		0x08
#define BLINK_REG_OFFSET	0x0C

#define BLINK_PERIOD		2				// period for LED blinking if blink_reg = 1 (counted in SLEEP_DT increments)
#define SHIFT_PERIOD		1				// period for shifting active LED strip part (counted in SLEEP_DT increments)
#define SLEEP_DT			100000			// time period for the periodic loop (in us)

// function for reading an AXI register
int read_reg (int base_addr, int offset)
	{
		int reg_value = 0;
		reg_value = Xil_In32(base_addr + offset);
		return reg_value;
	}

// function for writing into an AXI register
void write_reg (int base_addr, int offset, int reg_value)
	{
		Xil_Out32(base_addr + offset, reg_value);
	}

int main (void) {

	int dir = 0;							// direction register value (0x04)
	int non = 0;							// number of active LEDs register value (0x08)
	int blink = 0;							// blinking register value (0x0C)
	int led_val = 0;						// value to be written to led_reg (0x00)

	int start_ptr = 0;						// current beginning coordinate of the active LED strip part
	int led_vector[8] = {0};				// values of all LEDs

	int blink_count	= 0;					// counter for blinking
	int shift_count = 0;					// counter for shifting
	int blink_mask = 1;						// masking active LEDs for blinking

	while(1) {
		usleep(SLEEP_DT);

		dir = read_reg(BASE_ADDR, DIR_REG_OFFSET);
		non = read_reg(BASE_ADDR, NON_REG_OFFSET);
		blink = read_reg(BASE_ADDR, BLINK_REG_OFFSET);

		// Incrementing counters
		blink_count = blink_count + 1;
		shift_count = shift_count + 1;

		// Generating blink mask
		if (blink_count == BLINK_PERIOD) {
//			printf("counter_reset\n");
			blink_count = 0;
			if ((blink_mask == 1) & (blink == 1)) {		// only blinking when blink_reg = 1
				blink_mask = 0;
			}
			else {
				blink_mask = 1;
			}
		}

		// Shifting start position
		if (shift_count == SHIFT_PERIOD) {
			shift_count = 0;
			if (dir == 1) {
				start_ptr = start_ptr + 1;
				if (start_ptr > 7) {
					start_ptr = 0;
				}
			}
			else {
				start_ptr = start_ptr - 1;
				if (start_ptr < 0) {
					start_ptr = 7;
				}
			}
		}

		// Establishing which LEDs should be active:
		// First, constructing active LED vector at position = 0 (beginning of LEd strip)
		for (int i=0; i<8; i++) {
			led_vector[i] = 0;
			if (i < non) {
				led_vector[i] = blink_mask;
			}
		}

		// Second, shifting led_vector so that its beginning matches start_ptr
		int led_vector_temp[8] = {0};

		if (start_ptr != 0) {
			for (int i=0; i<start_ptr; i++) {

				for (int k=0; k<8; k++) {
					if (k == 0) {
						led_vector_temp[k] = led_vector[7];
					}
					else {
						led_vector_temp[k] = led_vector[k-1];
					}
				}

				// Assigning shifter temp values back to the led_vector array
				for (int i=0; i<8; i++) {
					led_vector[i] = led_vector_temp[i];
				}

			}
		}



		// Converting led_vector to a decimal value to be written to the led_reg
		led_val = 0;
		for (int i=0; i<8; i++) {
			led_val = led_val + led_vector[i]*pow(2, 7-i);
		}

		write_reg(BASE_ADDR, LED_REG_OFFSET, led_val);

	}

	return 0;
}

