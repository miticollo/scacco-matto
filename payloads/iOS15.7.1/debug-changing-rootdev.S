/* t8015_shellcode_arm64.S
 *
 * original author: axi0mX
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

.text
                                //\\                   iBoot64Patcher                            Note
.pool
.set JUMP_BACK,     0x180018004

.set WRITE_ADDR_1,  0x180030ad0 // rsa check           applying patch=0x180030ad0                img4interposercallbackmov
.set WRITE_ADDR_2,  0x180030b18 // rsa check           applying patch=0x180030b18
.set WRITE_ADDR_3,  0x180033e14 // bootargs            applying patch=0x180033e14                bootargstackvar
.set WRITE_ADDR_4,  0x18004d520 // bootargs str        applying patch=0x18004d520                Pointing default boot-args xref to
                                //                                                               Indirizzo in cui piazzare i bootargs. Precedentemente non usato: infatti sembrerebbe che una grossa porzione di iBoot (chiamiamola zeroBuf) e' composta di 0x00.
.set WRITE_ADDR_5,  0x1800949f4 // kernelcache str                                               xxd -g 4 -c 4 -o ${iboot_base_2nd_from_iboot64patcher} -e iboot.dec
.set WRITE_ADDR_6,  0x18003289c // debug               applying patch=0x18003289c

.set WRITE_VALUE_3, 0x100cb878  // insn                applying patch=0x180033e14 : 78b80c10
.set WRITE_VALUE_5, 0x64686361  // kernelc[achd]                                                 ultimi 4 byte (caratteri) della stringa "System/Library/Caches/com.apple.kernelcaches/kernelcache" quindi ache, che cambio in achd

.set MOV_X0_0,      0xd2800000  //                     applying patch=0x180030ad0 : 000080d2     mov x0, #0 
                                //                     applying patch=0x180030b18 : 000080d2
.set MOV_X0_1,      0xd2800020  //                     applying patch=0x18003289c : 200080d2     mov x0, #1

.globl _main
_main:
  MSR DAIFSET, #0xF

  LDR W6, =MOV_X0_0
  LDR X5, =WRITE_ADDR_1
  STR W6, [X5]
  LDR X5, =WRITE_ADDR_2
  STR W6, [X5]

  LDR X5, =WRITE_ADDR_3
  LDR W6, =WRITE_VALUE_3
  STR W6, [X5]

  LDR X5, =WRITE_ADDR_4    //                      Applying custom boot-args "keepsyms=1 debug=0x14e kextlog=0xffff serial=0x3 rd=disk0s1s8"
                           //                      Byte order: little endian.

  LDR W6, =0x7065656b      //       peek           Per maggiori dettagli: https://developer.arm.com/documentation/dui0473/m/writing-arm-assembly-language/load-immediate-values-using-ldr-rd---const
  STR W6, [X5]
  LDR W6, =0x736d7973      //       smys
  STR W6, [X5,#4]          //                      A word 4 bytes above the address in X5.
  LDR W6, =0x6420313d      //       d 1=
  STR W6, [X5,#8]          //                      A word 8 bytes above the address in X5.
  LDR W6, =0x67756265      //       gube
  STR W6, [X5,#12]         //                      A word 12 bytes above the address in X5.
  LDR W6, =0x3178303d      //       1x0=
  STR W6, [X5,#16]         //                      A word 16 bytes above the address in X5.
  LDR W6, =0x6b206534      //       k e4
  STR W6, [X5,#20]         //                      A word 20 bytes above the address in X5.
  LDR W6, =0x6c747865      //       ltxe
  STR W6, [X5,#24]         //                      A word 24 bytes above the address in X5.
  LDR W6, =0x303d676f      //       0=go
  STR W6, [X5,#28]         //                      A word 28 bytes above the address in X5.
  LDR W6, =0x66666678      //       fffx
  STR W6, [X5,#32]         //                      A word 32 bytes above the address in X5.
  LDR W6, =0x65732066      //       es f
  STR W6, [X5,#36]         //                      A word 36 bytes above the address in X5.
  LDR W6, =0x6c616972      //       lair
  STR W6, [X5,#40]         //                      A word 40 bytes above the address in X5.
  LDR W6, =0x3378303d      //       3x0=
  STR W6, [X5,#44]         //                      A word 44 bytes above the address in X5.
  LDR W6, =0x3d647220      //       =dr
  STR W6, [X5,#48]         //                      A word 48 bytes above the address in X5.
  LDR W6, =0x6b736964      //       ksid
  STR W6, [X5,#52]         //                      A word 52 bytes above the address in X5.
  LDR W6, =0x73317330      //       s1s0
  STR W6, [X5,#56]         //                      A word 56 bytes above the address in X5.
  LDR W6, =0x00000038      //       ...8
  STR W6, [X5,#60]         //                      A word 60 bytes above the address in X5.

  LDR X5, =WRITE_ADDR_5
  LDR W6, =WRITE_VALUE_5
  STR W6, [X5]

  LDR X5, =WRITE_ADDR_6
  LDR W6, =MOV_X0_1
  STR W6, [X5]


  LDR X5, =JUMP_BACK
  BR  X5
