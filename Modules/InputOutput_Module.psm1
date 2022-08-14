<#
Modulo que brinda funciones de operaciones sobre Input y Output de consola.
#>

#Guarda una credencial encriptada en un archivo.
function Store-PSCredential($Credential,$Path){
    $Name_Suffix=Get-Random -Maximum 99999999 -Minimum 11111111
    $Name_Prefix="pscrdenc"
    $File_Extension=""
    $FilePath=$Env:Temp
    if ($Path -eq $null){
        $Path=$FilePath+"\"+$Name_Prefix+$Name_Suffix+$File_Extension
    }
    $Credential | Export-CliXml -Path $Path
    if (-not(($?)-and(Test-Path $Path))){$Path=$False}
    Return $Path
}

#Recupera una credencial encriptada de un archivo
function Restore-PSCredential($Path){
    $Credential=$null
    if (Test-Path $Path){
        $Credential = Import-CliXml -Path $Path
        if (-not($?)){$Credential=$null}
    }
    Return $Credential    
}

#Normaliza o capitaliza un string, devolviendo cada palabra con su primer letra en mayusculas.
function Get-CapitalizedString($StringValue){
    $NewStringValue=$null

    #Verifica que sea un string
    if ($StringValue -is [String]){
        #Limpia el string de espacios al principio o al final
        $StringValue=($StringValue.Trimstart(" ")).TrimEnd(" ")
        #Arma un vector separando por espacios
        $Array=$StringValue -split " "
        #Recorre el vector, palabra a palabra
        foreach ($Word in $Array){
            #Pasa la palabra a minusculas
            $Word=$Word.tolower()
            #Prepara la primer letra en mayusculas
            $FirstLetter=($Word.substring(0,1)).toupper()
            #Reemplaza la letra en la palabra
            $Word=$FirstLetter+$Word.remove(0,1)

            #Concatena el string a devolver con la palabra
            $NewStringValue+="$Word "
        }
    }

    #Devuelve el original si no se logro armar
    if ($NewStringValue -eq $null){$NewStringValue=$StringValue}
    Return $NewStringValue
}

#Funcion que permite ingreso multi-linea
function Read-HostMultiLine($Message,$Clear=$true){
    $MultiLine=$null #Cadena que se utiliza para almacenar multi-linea
    $Auxiliar=$null #Cadena auxiliar
    #Si el mensaje esta vacio, muestra un default
    if ($Message -eq $null){$Message="Enter multi-line input and press [ENTER]:"}
    #Muestra mensaje de Input
    Write-Host $Message

    #Hace un ciclo mientras que la ultima linea ingresada no sea nula
    do {
        #Toma un ingreso de una linea y lo guarda en la variable auxiliar
        Read-Host | Set-Variable Auxiliar
        #Agrega el contenido de la variable auxiliar al de la variable multilinea, combinando con el caracter de nueva linea o CRLF
        Set-Variable -Name MultiLine -Value ($MultiLine+"`n"+$Auxiliar)
    }while($Auxiliar)

    #Limpia la pantalla, si esta activo
    if ($Clear){Clear}

    #Quita los renglones sobrantes al principio y al final
    $MultiLine = $MultiLine.trim()
    #Retorna resultado
    Return $MultiLine
}

#Reemplaza caracteres ilegales en un string
function Replace_Ilegal_Characters($String){
    #Lista de caracteres y sus reemplazos
    $CharacterDictionary=@{"á"="a";"é"="e";"í"="i";"ó"="o";"ü"="u";"ñ"="n";"-"="";"_"="";"."="";","="";"*"="";"#"="";"'"=""}
    
    #Verifica que el string no sea nulo
    $StringIsNotNull=(-not($String -eq $null))
    #Verifica que la variable sea string
    $VariableIsString=$String -is [String]

    #Solo si se cumplen las condiciones, aplica el cambio
    if ($VariableIsString -and $StringIsNotNull){
        #Reemplaza cada instancia de los caracteres en la lista sobre el string con su correspondiente suplente
        foreach ($Key in $CharacterDictionary.Keys){
            $Char_Replace=$Key #Caracter a reemplazar
            $Char_New=$CharacterDictionary[$Key] #Caracter suplente
            $String=$String.replace($Char_Replace,$Char_New) #Reemplaza el caracter
        }
    }

    #Devuelve el string modificado -o la variable original en caso de error-
    Return $String
}
