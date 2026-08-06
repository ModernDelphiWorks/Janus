{
      ORM Brasil: um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                        Version 3, 29 June 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       Everyone is permitted to copy and distribute verbatim copies
       of this license document, but changing it is not allowed.

       This version of the GNU Lesser General Public License incorporates
       the terms and conditions of version 3 of the GNU General Public
       License, supplemented by the additional permissions listed below.
}

{ 
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

{
  Windows MSWINDOWS
  macOS MACOS
  iOS IOS
  Android ANDROID
  Linux LINUX
}

{
  Compiler			CompilerVersion		Defined Symbol	Used BPL
  Delphi 12.? ??         	36 			VER360		29
  Delphi 11.1 Alexandria 	35 			VER350		28
  Delphi 10.4 Sidney     	34 			VER340		27
  Delphi 10.3 Rio		33 			VER330		26
  Delphi 10.2 Tokyo	 	32 			VER320		25
  Delphi 10.1 Berlin	 	31			VER310		24
  Delphi 10 Seattle	 	30			VER300          23
  Delphi XE8		 	29 			VER290          22
  Delphi XE7		 	28 			VER280          21
  Delphi XE6		 	27 			VER270          20
  Delphi XE5		 	26 			VER260          19
  Delphi XE4		 	25 			VER250          18 
  Delphi XE3		 	24 			VER240          17
  Delphi XE2		 	23 			VER230          16
  Delphi XE	        	22 			VER220          15
  Delphi 2010 	       		21 			VER210          14
}

{$DEFINE VCL}
{.$DEFINE FMX}
{.$DEFINE LOAD_DYNAMICALLY}
{.$DEFINE DRIVERRESTFUL}
{.$DEFINE USECLIENTDATASET}
{$IFNDEF USECLIENTDATASET}
  {$DEFINE USEFDMEMTABLE}
{$ENDIF}
{.$DEFINE MONITORRESTFULCLIENT}

{ WHICH IN-MEMORY DATASET - ONE CHOICE WITH TWO VALUES, NOT TWO SWITCHES

  USEFDMEMTABLE and USECLIENTDATASET are read by exactly one unit,
  Janus.Manager.DataSet, and defining BOTH leaves it unable to accept any
  dataset at all - it compiles both type gates into
  TManagerDataSet.ResolverDataSetType, and no one dataset satisfies both, so
  every AddAdapter call raises. That unit refuses to build on that
  combination; see #223.

  USEFDMEMTABLE is therefore defined only when USECLIENTDATASET is NOT. This
  is what makes the ClientDataSet configuration reachable the documented way.
  A project file carries USECLIENTDATASET in DCC_Define, and a DCC_Define can
  only ADD a symbol - it cannot take USEFDMEMTABLE away. With USEFDMEMTABLE
  defined unconditionally, every such project landed in the dead combination
  instead of the working one. Five Example .dproj files under
  Examples/Delphi/Data did exactly that, and all five use TClientDataSet.

  The delivered default is unchanged: with nothing defined from outside,
  USECLIENTDATASET is off and USEFDMEMTABLE is on.

  ORDER HERE IS LOAD-BEARING. JanusInstall rewrites these lines by scanning
  for the FIRST line whose text contains the symbol name and replacing that
  whole line (TfrmPrincipal.LigarDefineJanusInc). The toggle line for each
  symbol must therefore come BEFORE any other line mentioning it - which is
  why the USECLIENTDATASET toggle sits above the IFNDEF that reads it, and
  why this note sits below both. }

{$IFDEF FMX}
  {$DEFINE HAS_FMX}
{$ENDIF}
{$IFDEF VCL}
  {$IFDEF MSWINDOWS}   // Epic 25: VCL / HAS_VCL graphics (Vcl.Imaging) is Windows-only
  {$DEFINE HAS_VCL}
  {$ENDIF}
{$ENDIF}

{$IFDEF USEFDMEMTABLE}
  {$DEFINE USEMEMDATASET}
{$ENDIF}

{$IFDEF USECLIENTDATASET}
  {$DEFINE USEMEMDATASET}
{$ENDIF}

// Delphi 13.x (VER370)
{$IFDEF VER370}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
  {$DEFINE DELPHI25_UP}
  {$DEFINE DELPHI26_UP}
  {$DEFINE DELPHI27_UP}
  {$DEFINE DELPHI28_UP}
  {$DEFINE DELPHI29_UP}
  {$DEFINE DELPHI30_UP}
{$ENDIF}

// Delphi ???
{$IFDEF VER360}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
  {$DEFINE DELPHI25_UP}
  {$DEFINE DELPHI26_UP}
  {$DEFINE DELPHI27_UP}
  {$DEFINE DELPHI28_UP}
  {$DEFINE DELPHI29_UP}
{$ENDIF}

// Delphi Alexandria
{$IFDEF VER350}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
  {$DEFINE DELPHI25_UP}
  {$DEFINE DELPHI26_UP}
  {$DEFINE DELPHI27_UP}
  {$DEFINE DELPHI28_UP}
{$ENDIF}

// Delphi Sidney
{$IFDEF VER340}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
  {$DEFINE DELPHI25_UP}
  {$DEFINE DELPHI26_UP}
  {$DEFINE DELPHI27_UP}
{$ENDIF}

// Delphi Rio
{$IFDEF VER330}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
  {$DEFINE DELPHI25_UP}
  {$DEFINE DELPHI26_UP}
{$ENDIF}

// Delphi Tokyo
{$IFDEF VER320}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
  {$DEFINE DELPHI25_UP}
{$ENDIF}

// Delphi BERLIN
{$IFDEF VER310}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
  {$DEFINE DELPHI24_UP}
{$ENDIF}

// Delphi SEATLLE
{$IFDEF VER300}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
  {$DEFINE DELPHI23_UP}
{$ENDIF}

// Delphi XE8
{$IFDEF VER290}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
  {$DEFINE DELPHI22_UP}
{$ENDIF}

// Delphi XE7
{$IFDEF VER280}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
  {$DEFINE DELPHI21_UP}
{$ENDIF}

// Delphi XE6
{$IFDEF VER270}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
  {$DEFINE DELPHI20_UP}
{$ENDIF}

// Delphi XE5
{$IFDEF VER260}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
  {$DEFINE DELPHI19_UP}
{$ENDIF}

// Delphi XE4
{$IFDEF VER250}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
  {$DEFINE DELPHI18_UP}
{$ENDIF}

// Delphi XE3
{$IFDEF VER240}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
  {$DEFINE DELPHI17_UP}
{$ENDIF}

// Delphi XE2
{$IFDEF VER230}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
  {$DEFINE DELPHI16_UP}
{$ENDIF}

// Delphi XE
{$IFDEF VER220}
  {$DEFINE DELPHI14_UP}
  {$DEFINE DELPHI15_UP}
{$ENDIF}

//Delphi 2010
{$IFDEF VER210}
  {$DEFINE DELPHI14_UP}
{$ENDIF}

//Lazarus
{$IFDEF FCP}
  {$DEFINE DELPHI14_UP}
{$ENDIF}

{$IFDEF DELPHI15_UP}
  {$DEFINE FORMATSETTINGS}
{$ENDIF}

{$IFDEF DELPHI17_UP}
  {$DEFINE HAS_NET_ENCODING}
{$ELSE IFDEF DELPHI16_UP}
  {$DEFINE HAS_SOAP_ENCODING}
{$ELSE}
  {$DEFINE HAS_ENCDDECD}
{$ENDIF}
