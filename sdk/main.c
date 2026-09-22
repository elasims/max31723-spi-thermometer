#include "xparameters.h"
#include "xil_io.h"
#include <stdio.h>

#define BASEADDR   XPAR_MYIP_IIC_ELA_0_S00_AXI_BASEADDR
#define CTRL_OFF   0x00
#define DONE_OFF   0x04
#define RDATA_OFF  0x08

#define OP_START 0
#define OP_WRITE 1
#define OP_READ  2
#define OP_STOP  3

#define SLAVE_ADDR_W   0x38
#define SLAVE_ADDR_R   0x39
#define REG_GLOBAL_CFG 0x40
#define REG_DIRECTION  0x34
#define REG_VALUES     0x3A

void i2c_issue(int op, int data, int nack) {
    uint32_t ctrl = (op & 0x3) | ((data & 0xFF) << 2) | ((nack & 0x1) << 10);
    Xil_Out32(BASEADDR + CTRL_OFF, ctrl);
    while (!Xil_In32(BASEADDR + DONE_OFF)) { }
}

uint8_t i2c_last_read(void) {
    return (uint8_t)Xil_In32(BASEADDR + RDATA_OFF);
}

void i2c_write_reg(uint8_t reg_addr, uint8_t value) {
    i2c_issue(OP_START, 0, 0);
    i2c_issue(OP_WRITE, SLAVE_ADDR_W, 0);
    i2c_issue(OP_WRITE, reg_addr, 0);
    i2c_issue(OP_WRITE, value, 0);
    i2c_issue(OP_STOP, 0, 0);
}

uint8_t i2c_read_reg(uint8_t reg_addr) {
    i2c_issue(OP_START, 0, 0);
    i2c_issue(OP_WRITE, SLAVE_ADDR_W, 0);
    i2c_issue(OP_WRITE, reg_addr, 0);
    i2c_issue(OP_START, 0, 0);
    i2c_issue(OP_WRITE, SLAVE_ADDR_R, 0);
    i2c_issue(OP_READ, 0, 1);
    i2c_issue(OP_STOP, 0, 0);
    return i2c_last_read();
}

int main() {
    i2c_write_reg(REG_GLOBAL_CFG, 0x10);
    i2c_write_reg(REG_DIRECTION, 0x00);

    while (1) {
        int port;
        printf("Kacinci portu acmak istersiniz (0-7)? ");
        scanf("%d", &port);
        printf("PORT%d'yi VCC'ye baglayip Enter'a basin...\n", port);
        getchar();
        getchar();

        uint8_t vals = i2c_read_reg(REG_VALUES);

        printf("Acik portlar: ");
        int any = 0;
        for (int i = 0; i < 8; i++) {
            if (vals & (1 << i)) {
                printf("%d ", i);
                any = 1;
            }
        }
        if (!any) printf("(yok)");
        printf("\n");
    }

    return 0;
}
