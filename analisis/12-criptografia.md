# Plan de análisis 12 — Criptografía

- **Punto de vista:** Un reto de criptografía casi siempre es un error de implementación o de parámetros, no una ruptura del algoritmo. El objetivo es identificar el esquema (cifrado, modo, codificación, hash o RSA), localizar la debilidad (clave corta, nonce o IV repetido, oráculo de padding, exponente o módulo mal elegidos, hash sin sal) y aplicar el ataque clásico correspondiente hasta obtener el texto plano o la clave, y de ahí la bandera.
- **Cuándo aplicarlo:** Cuando el reto entregue ciphertext, claves públicas (n, e), hashes, parámetros de un esquema propio o un servicio que descifre o valide datos. Aplicar también cuando aparezcan nombres como AES, RSA, XOR, ECB, CBC, CTR, GCM, base64 o hashes. No aplicar si la única vía es romper un algoritmo moderno con parámetros correctos: en ese caso buscar primero el fallo en el resto del sistema.

## Preparación

1. Confirmar autorización: debe existir `ctf/SCOPE.md` confirmado que incluya el reto o el host. En este momento no existe `ctf/SCOPE.md` en el repositorio (búsqueda vacía), así que ningún objetivo queda autorizado todavía.
2. Crear un directorio de trabajo nuevo y vacío para cada reto, separado de los scripts. Guardar allí los artefactos (`ct.bin`, `pub.pem`, `hashes.txt`).
3. Instalar dependencias (ver Herramientas). Recomendado: entorno virtual de Python con `pycryptodome`, `gmpy2`, `sympy`, `owiener`, `requests`. Para lattices y factorizaciones complejas, SageMath en Kali/WSL.
4. Anotar todos los datos: longitud del ciphertext, codificación, cabeceras, tamaño de bloque, valores de n, e, c, IV o nonce, y si aparece un servidor que responde a errores.
5. Probar primero con datos de ejemplo propios (un cifrado conocido) para validar el script de ataque antes de tocar el objetivo. Esto evita falsos positivos y reduce peticiones a un oráculo remoto.

## Herramientas

| Herramienta | Para qué | Nativo Windows / Kali-WSL |
|---|---|---|
| Python 3 + pycryptodome | Cifrar/descifrar AES, RSA, modos ECB/CBC/CTR/GCM, pruebas propias [N: no verificado en esta sesión, pero la doc de modos está en la fuente 2] | Ambos (`py -m pip install pycryptodome`; en Kali `pip3`) |
| gmpy2 | Raíces enteras (`iroot`), aritmética grande rápida, pruebas de primalidad | Windows difícil (wheels disponibles en pip para la mayoría de versiones); Kali directo |
| SymPy | Factorización de números pequeños, `sympy.ntheory`, `integer_nthroot`, CRT | Ambos (pip) |
| SageMath | Lattices (LLL/BKZ), Coppersmith, álgebra de campos finitos, polinomios | Preferible Kali/WSL (instalación pesada en Windows) |
| RsaCtfTool | Batería de ataques RSA automatizada (Wiener, factores comunes, Hastad, módulo común, etc.) | Ambos en Python; en Windows conviene WSL. Fuentes: [Ganapati/RsaCtfTool](https://github.com/Ganapati/RsaCtfTool), [fork con opciones CLI](https://github.com/maple3142/RsaCtfTool) |
| owiener | Ataque de Wiener en Python (`attack(e, n)` devuelve d o None) | Ambos (pip). [PyPI owiener](https://pypi.python.org/pypi/owiener) |
| FactorDB | Buscar factorizaciones ya conocidas de n. Cliente `factordb-python` o API HTTP `/api` | Ambos. [Cliente](https://pypi.org/project/factordb-python), API citada por terceros en la [fuente 9] |
| xortool | Estimar longitud de clave en XOR repetido y probar caracteres | Ambos en Python 3 (verificar la versión/fork instalado; una ficha de PyPI indica que la 0.96 pide Python 2). [Repo hellman/xortool](https://github.com/hellman/xortool) |
| hashcat | Crackeo de hashes por GPU/CPU con modos numerados, reglas y máscaras | Windows (binario oficial, ideal con GPU); Kali directo. [Wiki](https://hashcat.net/wiki/doku.php?id=hashcat) |
| John the Ripper (jumbo) | Alternativa a hashcat con muchos formatos (zip, rar, KeePass, etc.) | Kali directo; Windows con binarios de terceros |
| CyberChef | Decodificar y probar cadenas de transformaciones (base64, hex, XOR, bifid, etc.) en el navegador [N: no verificado en esta sesión] | Ambos (web local) |
| openssl CLI | Descifrado rápido con AES, pruebas de formatos PEM/DER, `openssl rsa -text` | Ambos (en Windows, el de Git for Windows o el de WSL) |
| CryptoHack / cryptopals | Práctica y referencia de ataques por reto [N: no verificado en esta sesión] | Web |

## Procedimiento paso a paso

1. **Identificar el esquema.**
   - Codificación: `base64 -d`, `xxd -r -p`, patrones de longitud. Un texto que termina en `=` suele ser base64.
   - Longitud múltiplo de 16 bytes: AES o similar en modo de bloque. Longitud múltiplo de 8: DES o Blowfish.
   - Hash: longitud hex (32 = MD5, 40 = SHA-1, 64 = SHA-256). Usar `hashcat --example-hashes` y `grep` para comparar formatos.
   - Clave pública: `openssl rsa -pubin -in pub.pem -text -noout` o `openssl asn1parse` para obtener n y e.

   ```bash
   hashcat --example-hashes | grep -B1 -i "Hash-mode\|example" | head -n 20
   openssl rsa -pubin -in pub.pem -text -noout
   ```

2. **Elegir el ataque según la debilidad.**

   **a) Cifrado clásico (César, Vigenère, sustitución, transposición).**
   - Análisis de frecuencias y ataque de diccionario. Para César, probar las 25 rotaciones.
   - CyberChef con "Caesar Box" o "Vigenère Decode" para una revisión visual rápida.

   **b) XOR de clave corta (repetida).**
   - Sin clave conocida, estimar la longitud con distancia de Hamming entre bloques o con xortool:

   ```bash
   xortool -l 5 ct.bin              # si ya conoces la longitud
   xortool -m 32 -c 20 ct.bin       # estima longitud; -c 20 = espacio (carácter más común en texto)
   xortool -l 5 -o ct.bin           # prueba caracteres imprimibles para la clave
   ```

   - Con clave de un byte, fuerza bruta en Python:

   ```python
   ct = open("ct.bin", "rb").read()
   for k in range(256):
       pt = bytes(b ^ k for b in ct)
       if all(32 <= c < 127 or c in b"\n\r\t" for c in pt):
           print(hex(k), pt)
   ```

   - Con texto plano conocido (crib) parcial: `key = bytes(a ^ b for a, b in zip(ct, crib))`, luego repetir la clave.

   **c) ECB.**
   - Detectar bloques repetidos (mismos 16 bytes en posiciones distintas indican ECB con texto plano repetido).
   - Si hay un oráculo que añade texto controlado antes del secreto (byte-at-a-time), recuperar el secreto byte a byte.
   - Cortar y pegar bloques en servicios que permiten entradas controladas.

   ```python
   from collections import Counter
   def repeated_blocks(data, bs=16):
       blocks = [data[i:i+bs] for i in range(0, len(data), bs)]
       return {b: n for b, n in Counter(blocks).items() if n > 1}
   ```

   **d) Reuso de nonce o IV (CTR, stream, CBC con IV fijo).**
   - Si c1 y c2 usan la misma keystream: `c1 ^ c2 == m1 ^ m2`. Con un texto conocido o "crib dragging" (arrastrar palabras probables) se recupera la keystream.

   ```python
   x = bytes(a ^ b for a, b in zip(c1, c2))  # = m1 XOR m2
   ```

   - GCM con nonce repetido: el ataque "forbidden" (Joux) permite recuperar la clave de autenticación H y falsificar etiquetas. Ver fuentes 6 y 7. Implementar solo con referencia directa a un paper o a un script verificado.

   **e) Padding oracle (CBC).**
   - Confirmar el oráculo: enviar ciphertexts modificados y observar un error distinto para padding válido e inválido.
   - Descifrar un bloque byte a byte: para cada posición, probar valores en el IV previo hasta que el padding sea válido, luego derivar el byte del texto plano.

   ```python
   def decrypt_block(c_block, oracle):
       # oracle(iv, c) -> True si el padding es válido
       inter = bytearray(16)
       for pos in range(15, -1, -1):
           pad = 16 - pos
           probe = bytearray(16)
           for i in range(pos + 1, 16):
               probe[i] = inter[i] ^ pad
           for g in range(256):
               probe[pos] = g
               if oracle(bytes(probe), c_block):
                   # descartar falso positivo con el byte previo cuando pad == 1
                   if pos == 15:
                       probe[14] ^= 1
                       if not oracle(bytes(probe), c_block):
                           continue
                   inter[pos] = g ^ pad
                   break
       return bytes(inter)  # texto plano = inter XOR IV_real del bloque anterior
   ```

   - Ver implementación completa y explicación en [flast101](https://flast101.github.io/padding-oracle-attack-explained) y en [NCC Group](https://nccgroup.com/sg/research-blog/cryptopals-exploiting-cbc-padding-oracles). El código anterior es un esquema para validar la lógica, no un exploit probado.

   **f) RSA débil.**
   - Primero comprobar n en FactorDB o factorizar si es pequeño (SymPy `factorint` hasta unos 10^20 con paciencia).
   - e pequeño y sin padding (m^e < n): raíz e-ésima entera.

   ```python
   import gmpy2
   m, exact = gmpy2.iroot(c, e)   # exact es True si la raíz es entera
   print(bytes(int(m)))
   ```

   - d pequeño (Wiener): `owiener.attack(e, n)` o `RsaCtfTool --attack wiener`.
   - Módulo común (mismo n, dos e coprimos): algoritmo de Euclides extendido.

   ```python
   def egcd(a, b):
       if b == 0:
           return a, 1, 0
       g, x, y = egcd(b, a % b)
       return g, y, x - (a // b) * y

   g, s, t = egcd(e1, e2)
   assert g == 1
   if s < 0:
       c1, s = pow(c1, -1, n), -s
   if t < 0:
       c2, t = pow(c2, -1, n), -t
   m = (pow(c1, s, n) * pow(c2, t, n)) % n
   ```

   - p y q cercanos: método de Fermat (`a = isqrt(n) + 1`, incrementar hasta que a² − n sea cuadrado).
   - Factores comunes entre varias claves: `gcd(n1, n2)`.
   - Si n se factoriza en p, q: `d = pow(e, -1, (p-1)*(q-1))` y luego `pow(c, d, n)`.

   **g) Hash.**
   - Ver si el hash es sin sal y si aparece en listas conocidas (FactorDB no aplica a hashes; usar listas y reglas de hashcat).
   - Ataque de diccionario con reglas:

   ```bash
   hashcat -m 0 -a 0 hashes.txt rockyou.txt -r rules/best64.rule     # MD5
   hashcat -m 1400 -a 3 hashes.txt ?l?l?l?l?l?l?d?d                    # SHA-256, máscara
   ```

   - Verificar el modo exacto con `--example-hashes` antes de lanzar el ataque. Los números de modo citados aquí (0 MD5, 1400 SHA-256) son conocidos, pero confirmarlos en la versión instalada.

3. **Resolver y verificar.**
   - Comprobar que el texto plano sea legible o que el hash coincida (`hashlib.sha256(pw).hexdigest()`).
   - Extraer la bandera con el formato del reto (por ejemplo `flag{...}` o `CTF{...}`). Si el resultado no tiene formato, volver al paso 1 con otro esquema.
   - Documentar el comando o script que dio la bandera.

## Qué buscar (indicadores de debilidad)

- Ciphertext idéntico en bloques repetidos o patrones visibles (ECB).
- Dos ciphertexts con el mismo nonce, IV o prefijo de keystream; longitud de `c1 ^ c2` que revela texto legible.
- Mensaje de error diferente según la validez del padding, o tiempos distintos (oráculo).
- Clave o IV fijos en el código fuente o en el enunciado.
- e = 3, 5, 17 o un n que se repite entre claves; e grande relativo a n (sospecha de d pequeño cuando e ≈ n).
- Primos p y q muy cercanos; n que aparece en FactorDB ya factorizado.
- Hashes sin sal, MD5 o SHA-1 sin iteraciones.
- Codificación disfrazada de cifrado (base64, hex, rot13 anidados).
- Mismo número de bytes en el texto plano que en la clave: señal de OTP mal usado (reuso de clave).

## Cómo interpretar y resolver

- **Éxito:** una cadena legible, una factorización válida (p·q = n con p y q primos), un hash que coincide con el original o una bandera con formato. Verificar siempre con una segunda comprobación.
- **Falso positivo:** en XOR, claves con caracteres no imprimibles; en padding oracle, el byte 0x01 en el último bloque; en Wiener, d que no descifra correctamente. Validar con un segundo mensaje.
- **Sin resultado:** cambiar de esquema. Si el ataque clásico falla, revisar si el enunciado da pistas (nombre del reto, cabecera, metadatos del archivo) y volver a identificar.
- **Límites:** Coppersmith, LLL y factorización general exigen parámetros grandes o tiempo. Si n tiene más de unos 512 bits sin factores pequeños, no esperar que hashcat o SymPy lo resuelvan.

## Errores comunes y trampas

- Confundir codificación con cifrado: base64 y hex no ocultan nada. Decodificar antes de atacar.
- Usar `int.to_bytes` o `bytes(int)` sin calcular la longitud correcta; leer la salida como ASCII en hex puede engañar.
- Usar `pow(a, -1, n)` sin comprobar que `gcd(a, n) == 1`.
- Usar `math.isqrt` en versiones antiguas de Python (disponible desde 3.8).
- En RSA, comprobar que los primos sean realmente primos (`gmpy2.is_prime`, `sympy.isprime`) antes de calcular d.
- Olvidar que PyCryptodome puede generar nonces de longitud distinta a la esperada en GCM (las fuentes no coinciden sobre el valor por defecto; verificar con `len(cipher.nonce)`).
- Atacar con demasiadas peticiones a un oráculo remoto sin limitar la tasa; puede bloquearse el servicio o el reto.
- Confiar en una herramienta sin validar: RsaCtfTool y xortool tienen forks con opciones distintas.
- Hashcat con modo equivocado: el resultado parece "no encontrado" en lugar de dar error.
- Windows: rutas con espacios y `Set-Content` que altera saltos de línea y bytes; leer y escribir ciphertexts siempre en binario (`rb`/`wb`).

## Fuentes

Verificadas en esta sesión (búsqueda o documentación consultada):

1. [RsaCtfTool — Ganapati/RsaCtfTool](https://github.com/Ganapati/RsaCtfTool) (repo y lista de ataques vistos en búsqueda; la lista exacta debe confirmarse en el README oficial).
2. [pycryptodome — Modern modes of operation](https://pycryptodome.readthedocs.io/en/latest/src/cipher/modern.html) (API GCM y nonce; el valor por defecto de nonce es contradictorio entre fuentes).
3. [owiener en PyPI](https://pypi.python.org/pypi/owiener) y [rsa-wiener-attack (pablocelayes)](https://github.com/pablocelayes/rsa-wiener-attack).
4. [Wiener's attack — Wikipedia](https://en.wikipedia.org/wiki/Wiener%27s_attack) y [Sagi Kedmi, Wiener's RSA attack](https://sagi.io/crypto-classics-wieners-rsa-attack).
5. [xortool — hellman/xortool](https://github.com/hellman/xortool) y [Didier Stevens, XOR known-plaintext attack](https://blog.didierstevens.com/2016/01/01/xor-known-plaintext-attack/).
6. [Black Hat 2016, Devlin — Nonce Disrespecting Adversaries (GCM en TLS)](https://www.blackhat.com/docs/us-16/materials/us-16-Devlin-Nonce-Disrespecting-Adversaries-Practical-Forgery-Attacks-On-GCM-In-TLS-wp.pdf).
7. [Eurocrypt 2015, Twisted Polynomials and Forgery Attacks on GCM](https://www.iacr.org/archive/eurocrypt2015/90560260/90560260.pdf) y [CVE-2016-10212 (NVD)](https://nvd.nist.gov/vuln/detail/CVE-2016-10212) como caso real de reuso de nonce.
8. [hashcat wiki](https://hashcat.net/wiki/doku.php?id=hashcat) y [man page de hashcat (Debian)](https://dyn.manpages.debian.org/bullseye/hashcat/hashcat.1.en.html) (`--example-hashes`).
9. [factordb-python en PyPI](https://pypi.org/project/factordb-python) (cliente con la API de FactorDB; la ficha indica una última versión antigua; el endpoint `/api` se cita por terceros).
10. [flast101, Padding Oracle Attack explained](https://flast101.github.io/padding-oracle-attack-explained) y [NCC Group, Cryptopals exploiting CBC padding oracles](https://nccgroup.com/sg/research-blog/cryptopals-exploiting-cbc-padding-oracles).

No verificadas en esta sesión (mencionadas por conocimiento general, confirmar antes de usar):

- CyberChef (https://gchq.github.io/CyberChef/), SageMath (https://www.sagemath.org/), CryptoHack (https://cryptohack.org/), cryptopals (https://cryptopals.com/).
- Modos de hashcat para MD5 (0), SHA-256 (1400) y la regla `best64.rule`.
- Método byte-at-a-time para ECB y el ataque de Hastad con raíz e-ésima.

## Relación con otros planes

- Plan 02 (red y conexiones): ver [analisis/02-red-conexiones.md](../analisis/02-red-conexiones.md). Los servicios que exponen oráculos de padding o cifrados propios se identifican allí.
- Plan 05 (bases de datos y consultas): ver [analisis/05-bases-datos-consultas.md](../analisis/05-bases-datos-consultas.md). Los hashes de contraseñas almacenados se derivan de ese flujo.
- Plan 07 (OSINT y reconocimiento): ver [analisis/07-osint-reconocimiento.md](../analisis/07-osint-reconocimiento.md). Las claves públicas, certificados o correos que aparecen en fuentes abiertas alimentan los ataques RSA.
- Otros planes (web, pwn, rev, forense, stego) no se revisaron en esta sesión; los retos de criptografía con archivos ocultos o metadatos deben derivarse al plan de forense o esteganografía correspondiente.

## Autorización

- Este plan es metodológico y no apunta a ningún objetivo concreto.
- Ningún ataque debe ejecutarse contra un servicio, host o reto sin que `ctf/SCOPE.md` esté confirmado y listado. En este momento no existe `ctf/SCOPE.md` en el repositorio.
- Las pruebas contra oráculos remotos deben limitarse al alcance confirmado y a la tasa que el reto permita.
- Las recomendaciones de este plan son propuestas pendientes de aprobación del usuario y de la ejecución de Codex dentro del alcance.
