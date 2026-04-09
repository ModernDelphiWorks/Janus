{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Core.Consts;

interface

uses
  TypInfo;

const
  cENUMERATIONSTYPEERROR = 'Invalid type. Type enumerator supported [ftBoolean, ftInteger, ftFixedChar, ftString]';
  cMESSAGEPKNOTFOUND = 'PrimaryKey not found on your model!';
  cMESSAGECOLUMNNOTFOUND = 'Nenhum atributo [Column()] foi definido nas propriedades da classe [ %s ]';
  cPROPERTYTYPES_1 = [tkUnknown,
                      tkInterface,
                      tkClass,
                      tkClassRef,
                      tkPointer,
                      tkProcedure];

  cPROPERTYTYPES_2 = [tkUnknown,
                      tkInterface,
                      tkClassRef,
                      tkPointer,
                      tkProcedure];


implementation

end.
