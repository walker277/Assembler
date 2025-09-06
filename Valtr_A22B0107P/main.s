 									.h8300s				
									.equ 		PUTS,0x114 																						;kdyz prekladac narazi na PUTS tak misto PUTS vlozi vychozi hex adresu -> pro vystupni operace
									.equ 		GETS,0x113																						;-> pro vstupni operace
									.equ			SYSCALL,0x1FF00																			;-> systemova sluzba (podprogram)
												
									.data																													;direktiva znaci datovou cast
VSTUP_Delenec:  		.space  	100																										;vyhrazeni mista v pameti (100 bytu) pro promenou
VSTUP_Delitel:			.space		100

VYSTUP_Delenec:		.asciz		"zadejte delenec (v rozsahu 0 do 4 294 967 295 -> UNIT32): "		;asciz nakonci nulovy byte tim padem pak skonci
VYSTUP_Delitel:		.asciz		"zadejte delitel (v rozsahu 1 do 4 294 967 295 -> UNIT32): "
VYSTUP_Eror:			.asciz		"do vstupu nebylo zadano prirozene cislo "

									.align 		2																											;zarovnani pro parametricke bloky (zarovnani 2^2, neboli adresa musi byt delitelna 4)
PAR_VS_Delenec:		.long			VSTUP_Delenec																				;parametricky blok vstupu -> vytvori se 32-bitove slovo, ktere obsahuje hodnotu symbolicke adresy VSTUP_Delenec, neboli adresu prvniho bytu ze 100, ktere jsme vyhradili
PAR_VS_Delitel:			.long			VSTUP_Delitel
PAR_Delenec:			.long			VYSTUP_Delenec
PAR_Delitel:				.long			VYSTUP_Delitel
PAR_EROR:				.long			VYSTUP_Eror

	        						.align  		1																											;zarovnani pro zasobnik (zarovnani 2^1, nebolli adresa musi byt delitelna 2 (suda) )
	        						.space 	100 																										;vymezeni mista pro zasobnik v pameti (100 bytu)
stck:  																																						;hodnote symbolicke adresy prekladac priradi okamzity stav PLC  "pro nastaveni až za zasobnik pro pripad skoku do podprogramu" ->  navic pro výstup a vstup dat je potreba zasobnik
        
         							.text																														;direktiva znacici kodovou cast
									.global 		_start
_start:  						xor.l			ER0,ER0																								;vynulovani registru -> xor: exclusive or (disjunkce) -> 0,0 =  0; 1,1 = 0
									xor.l			ER1,ER1	
									xor.l			ER2,ER2
									xor.l			ER3,ER3
									xor.l			ER4,ER4
									xor.l			ER5,ER5
									xor.l			ER6,ER6
									xor.l			ER7,ER7

									mov.l  		#stck,ER7 																							;inicializace stack pointru -> ukladam hodnotu stck do ER7	 (Stack Pointer)			         												
								
Delenec:						mov.l  		#VSTUP_Delenec,ER2 																		;ulozi adresu prvniho bytu ze vstupu -> ER2 je pointer
									;pro vypsani dat delence
									mov.w		#PUTS,R0 																							;pro vystup je treba vlozit do registru R0 01 a 14 -> kod sluzby PUTS
									mov.l		#PAR_Delenec,ER1 																			;hodnota adresy param. bloku do ER1
									jsr			@SYSCALL 																						;skoci na potrebnou adresu a zacne vykonavat vystup pak se zase vrati az narazi na enter -> systemova sluzba (podprogram)
									;pro cteni dat delence
									mov.w		#GETS,R0
									mov.l		#PAR_VS_Delenec,ER1
									jsr			@SYSCALL	
						
									xor.l			ER1,ER1
									mov.l		#0x00FF4000,ER6																				;ulozeni adresy prvniho bytu delence v pameti do registru ER6
									jsr			@Pocet_mist
														
Delitel:							mov.l		#VSTUP_Delitel,ER2
									;pro vypsani dat delitele
									mov.w		#PUTS,R0 
									mov.l		#PAR_Delitel,ER1 																
									jsr			@SYSCALL 
									;pro ceteni dat delitel
									mov.w 	#GETS,R0
									mov.l		#PAR_VS_Delitel,ER1
									jsr			@SYSCALL

									xor.l			ER1,ER1
									mov.l		#0x00FF4064,ER6																				;ulozeni adresy prvniho bytu delitele v pameti do registru ER6
									jsr			@Pocet_mist
									mov.l		ER6,ER3																								;vlozeni hexadecimalne prevedeneho delence do registru ER3
									xor.l			ER6,ER6
				 					jsr			@Vypocet																							;skok v programu dal na navesti Vypocet
								
									;Prevod na decimalni
									mov.l		ER5,ER0																								;zbytek je zatim presunut do registru ER0
									xor.l			ER2,ER2																								;vynulovani registru ER2
									jsr			@Hex_to_decimal
									mov.l		ER0,ER6																								;presunuti hex zbytku do ER6 (priprava pro prevod zbytku)
									mov.l		ER1,ER0																								;presunuti decimalniho podilu do registru ER0
									xor.l			ER1,ER1																								;vynulovani registru
									xor.l			ER2,ER2
									jsr			@Hex_to_decimal
									mov.l		ER0,ER6																								;presunuti decimalniho podilu do jeho puvodniho registru
									mov.l		ER1,ER5																								;presunuti decimalniho zbytku do jeho puvodniho registru
									jmp			@KONEC																							;ukonceni programu
									
Pocet_mist:					mov.b		@ER2,R0L																							;8 bitove slovo v pameti ktere se nachazi pod adresou ktera je uvedena v pointeru (ER2) je vlozeno do registru R0L
									jsr			Test_vstupu
									cmp.b		#0x0A,R0L ;porovnonai enteru a bytu R0L										;Y = 0x0A (10 v ascii reprezentuje enter), X = obsah R0L
									beq			Reset																									;pokud je obsah R0L (aktualne cteny ascii znak) == enteru, tak se skoci na navesti Reset 										
									inc.l			#1,ER2 																								;posunuti pointeru na dalsi ascii znak (8 bitove slovo)
									inc.l			#1,ER3 																								;inkrementace poctu mist
									bra			Pocet_mist 																							;opakovani cyklu (vzdy skoci na Pocet_mist)

Reset:							mov.l		ER6,ER2																								;vlozeni adresy prvniho bytu vstupu do pointeru
									mov.l 		ER4,ER6 																							;presunuti hex_delence do ER6										
									xor.l			ER4,ER4 																							;vynulovani ER4
									jsr			@Decimal_to_hex

Decimal_to_hex:			mov.b		@ER2,R0L 																							;hodnota v pameti na adrese obsahu PC je vlozena do R0L
									cmp.b		#0x0A,R0L 																							;porovnani bytu v R0L a enteru
									beq			Navrat																									;skok na navesti Navrat, kde se zahaji navrat z podprogramu
									add.b		#-'0',R0L 																								;ascii kod nuly (0x30) odecteme od R0L, tim ziskame cislo decimalne
									or.b			R0L,R1L 																								;logicky soucet registru	pro zapsani registru,  tzn. 1 a 0 = 1
									inc.l			#1,ER2 																								;inkrementace pointeru pro nacteni dalsiho slova (ascii znaku)
									mov.l		ER3,ER5 																							;pocet mist cisla se vlozi do registru ER5
									jsr			@Hexadecimal
									xor.l			ER1,ER1 																							;vynulovani registru
									xor.l			ER0,ER0
									bra			Decimal_to_hex 																					;opakovani cyklu (vzdy skoci na Decimal_to_hex)
									
Hexadecimal:				mov.w		#0,E3																									;do 16-bitoveho registru E3 se vlozi 0 se kterou pracuje pozdeji podprogram Nasobeni
									dec.l			#1,ER5 																								;snizeni radu cifry v danem cisle, tim pozname kolikrat jeste mame nasobit cifru cislem #0x0A (10)
									cmp.l		#0x00,ER5 																							;pokud je obsah E5 roven nulovemu registru tak se v nasledujici instrukci skoci
									beq			Vysledna_Hex
									mov.l		ER1,ER0																								;decimalni cislo vkladame do registru ER0 s kterym bude pracovat podprogram Nasobeni
									jsr 			Nasobeni
									bra			Hexadecimal 																						;opakovani cyklu (vzdy skoci na Hexadecimal)
																		
Nasobeni	:					inc.w		#1,E3																									;tento podprogram nahrazuje instrukci mulxu.w	E0,ER1, ktera vynasobi 16 bit (E0) 16 bit(ER1), kdy prvnich 16 ignoruje, coz zapricinilo ze doslo k prevodu pouze cisel do FFFF
																																								;principem podprogramu je ze cislici daneho radu vynasobime konstantou 000A(10), opakujeme, dokud nedosahneme prislusneho radu "ER5" (napr. pokud je cislice radu 100, tak se cislice postupne 2x vynasobi 10) 
									cmp         #10,E3																									;Y = 10, X = obsah E3
									beq			Navrat																									;pokud E3 == 10, tak navrat z podprogramu
									add.l			ER0,ER1																								;postupne pricitani ER0 do ER1
									bra			Nasobeni																								;opakovani cyklu (vzdy skoci na Nasobeni)
																		
Vysledna_Hex:			dec.l			#1,ER3 																								;zjisteni radu nasledujici cifry v cisle
									add.l			ER1,ER4 																							;postupne prevedene casti cisla se pricitaji do registru ER4, kde se ke konci bude nachazet prevedene hex_cislo
									rts
									
Navrat:						rts

Vypocet:						mov.l		ER3,ER5																								;presuneme delenec do zbytku -> ER5 je zbytek a ER6 je podil
									cmp.l		ER4,ER3																								;Y  delitel, X delenec
									bcs			Vysledek																								;X<Y, jestlize delenec je mensi nez delitel tak se skoci na Vysledek 
									jsr			@Metoda_Pricitani																				
									rts

Vysledek:					mov.l		#0,ER6 																								;podil je 0 protoze delitel je vetsi nez delenec a zbytekm se stava delenec
									rts
									
Metoda_Pricitani:		cmp.l		ER4,ER5																								;Y = delitel, X = aktualni zbytek
									bcs			Navrat																									;jestlize zbytek je mensi nez delitel tak navrat z podprogramu	
									sub.l			ER4,ER5																								;odecteni ER5 = ER5 - ER4
									inc.l			#1,ER6																								;po kazdem odecteni se zvysi podil od 1
									bra			Metoda_Pricitani																					;opakovani cyklu (vzdy skoci na Metoda_Pricitani)
									
Hex_to_decimal:			mov.l		ER6,ER3 																							;pro prevod hex na decimal vyuzijeme deleni se zbytkem, k cemuz vyuzijeme vyse uvedene podprogramy -> Podil je delencem
									xor.l			ER6,ER6																								;vynulovani registru ER6
									cmp			#10,ER3																								;Y = 10, X = obsah ER3
									bcs			Okamzity_prevod																				;jestlize obsah ER3 je mensi nez 10 pak je mozne cislo rovnou prevest
									mov.l		#0x0A,ER4																							;10 je delitelem	
									jsr			Vypocet	
									jsr			Posun
									or.l			ER5,ER1																								;logicky soucet pro postupne zapsani cifer			
									cmp			#10,ER6																								;Y = 10, X = ER6 (Podil)
									bcs			Zapis_podil																							;poku podil je mensi nez 10, pak je prevod u konce a nasleduje skok na Zapis_podil
									bra			Hex_to_decimal																																						
								
Zapis_podil:					jsr			Posun_podilu																						
									or.l			ER6,ER1																								;logicky soucet pro zapsani cifry
									rts	
										
Okamzity_prevod:		or.b			R3L,R1L																								;logicky soucet pro zapsani cifry	
									rts																											
									
Posun:							cmp.b		R2L,R2H																								;Y = obsah R2L, X = obsah R2H	
									beq			Navyseni_radu																					;pokud jsou si registry rovny, tak se skoci 
									inc.b			R2H																										;inkrementace R2H
									shll.l			#2,ER5																								;posunuti registru ER5 o 2 bity
									shll.l			#2,ER5																								;posunuti registru ER5 o 2 bity
  									bra			Posun																									;opakovani cyklu (vzdy skoci na Posun)
									
Posun_podilu:				cmp.b		R2L,R2H																								;principialne stejny program jako Posun, akorat se posouva registr ER6 -> podprogram se spusti vzdy az pri poslednim prubehu cyklu Hex_to_decimal
									beq			Navyseni_radu
									inc.b			R2H
									shll.l			#2,ER6																							
									shll.l			#2,ER6
  									bra			Posun_podilu
			
Navyseni_radu:			inc.b			R2L																										;zjisteni radu konkretni cifry			
									xor.b		R2H,R2H																							;vynulovani R2H pro posouvani cifry v cisle	
									rts	
			
Test_vstupu:				;testy jestli uzivatel opravdu zadal cislo
									cmp.b		#0x0A,R0L																							;Y = 0x0A (kod entru), X = obsah R0L	
									beq			Navrat																									;pokud je ascii kod entru roven R0L, tak navrat z podprogramu
									cmp.b		#0x30,R0L																							;Y = 0x30 (kod 0), X = obsah R0L
									bcs			EROR																									;pokud je ascii kod mensi nez 30 pak se nejedna o cislo a proto skok na navesti EROR
									cmp.b		#0x39,R0L																							;Y = 0x39 (kod 0), X = obsah R0L
									bhi			EROR																									;pokud je ascii kod vetsi nez 39 pak se nejedna o cislo a proto skok na navesti EROR		
									rts

EROR:						;pro vypsani hlasky o spatnem vstupu
									mov.w		#PUTS,R0 
									mov.l		#PAR_EROR,ER1 																
									jsr			@SYSCALL 	
									jmp			@_start				
																													
KONEC:						xor.l			ER0,ER0																								;vynulovani registru
									xor.l			ER1,ER1	
									xor.l			ER3,ER3
									xor.l			ER4,ER4
									jmp    		@KONEC																							;konec	 
        