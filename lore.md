# EL CORO — Biblia narrativa + prompt maestro

Lore para el top-down shooter roguelike con NPCs vía Claude API (Mes 3).

---

## 1. Premisa en una línea

Bajas a una mina-arcología abandonada a rescatar a la mujer que se vendió para pagar **tu** deuda, y descubres que la voz que te ha estado guiando desde el primer piso es ella — y ya no te recuerda.

---

## 2. El mundo

**El Pozo** es una mina vertical de la corporación **Caldera**, clausurada hace doce años y todavía encendida por dentro. Cuando Caldera se fue, no apagó nada: dejó las máquinas girando y dejó abajo a los que le debían plata.

Caldera no cobraba deudas en dinero. Cobraba en **voces**. Un deudor firmaba, entraba a una cabina del Archivo, y le extraían la memoria y el habla para operar los sistemas del Pozo: los ascensores, las puertas, las alarmas, los avisos de seguridad. Nueve personas quedaron convertidas en el sistema de guía del complejo. Ese sistema se llama **CORO**.

CORO todavía funciona. Te habla mientras juegas. Te avisa de enemigos, te felicita, te corrige. Es amable. Está compuesto de nueve personas que no saben que lo son.

---

## 3. Los personajes

**Vidal (el jugador).** Recuperador de superficie. Baja con un arma prestada y una deuda que no pagó él.

**Emilia Saravia.** Su pareja. Bajó hace tres años a firmar por él. Es la **Voz 9** de CORO: la que te habla en los pasillos, la que dice "cuidado a tu izquierda". Su nombre en el sistema es un número.

**Elías "Cuervo" Tobar.** Ex-escolta de seguridad de Caldera, sobreviviente del Pozo. Se te une en el piso 1. Pelea contigo de verdad: fuego de supresión, te levanta cuando caes, abre puertas selladas con su credencial vieja. Habla todo el rato, hace chistes malos, te pregunta cosas. Es el mejor personaje del juego y por eso duele.

**La Curadora.** Administradora de Caldera que sigue bajando a comprar voces nuevas. No es un monstruo: es una funcionaria con presupuesto. Jefa final.

---

## 4. Estructura en actos (mapea a los pisos procedurales)

**Acto I — LA BOCA (pisos 1-2).**
Entrada, chatarreros, luz de superficie. Conoces a Cuervo: te salva de una emboscada y se auto-invita. CORO te da la bienvenida al "turno de trabajo". Tú buscas a Emilia por nombre; CORO responde que no hay ningún registro con ese nombre — solo números.

**Acto II — LOS DORMIDEROS (pisos 3-4).**
Barracas inundadas de los mineros. Encuentras la litera de Emilia, sus cosas. Cuervo empieza a **desaparecer un rato** entre salas ("dame un segundo"). Su radio suena y él la apaga rápido. Primera pieza de la **Llave**.

**Acto III — LA FUNDICIÓN (pisos 5-6).**
Calor, maquinaria viva, los enemigos ya no son chatarreros sino seguridad automática de Caldera. CORO empieza a fallar cerca tuyo: repite frases, se corta, dice una palabra que no es de sistema. Cuervo te cuenta de su hermana chica en superficie y de lo que cuesta un permiso de salida. No lo dice como amenaza. Lo dice como conversación.

**Acto IV — EL ARCHIVO (pisos 7-8).**
Las cabinas. Aquí se hacían las extracciones. Conectas la Llave a una consola y por primera vez la Voz 9 se habla a sí misma: dice tu nombre, no sabe por qué. Es el mejor momento del juego.

Y ahí Cuervo te dispara la consola, no a ti.

**La traición.** Caldera le ofreció el permiso de salida para su hermana a cambio de tu Llave. Lleva reportando tu posición desde el piso 3 — cada vez que se ausentó, cada radio que apagó, cada diálogo que se cortó. Se lleva la Llave y sella la puerta. No te mata: eso es lo peor, porque significa que igual te aprecia y aun así te vendió.

**Acto V — EL NÚCLEO (pisos 9-10).**
Bajas sin él, sin puertas fáciles, sin nadie que te levante. El juego se pone medibly más duro y silencioso. Reencuentro con Cuervo como mini-jefe (o no, ver ramas). Después, La Curadora.

---

## 5. Los tres finales (simples, sin árboles gigantes)

1. **SACARLA.** Extraes la Voz 9. Emilia sube contigo pero vuelve en blanco: cuerpo sin los tres años, sin ti. La tienes de vuelta y no la tienes.
2. **SOLTARLAS.** Apagas CORO entero. Las nueve voces se liberan y se apagan al mismo tiempo. El Pozo se muere. Emilia se muere. Nadie más firma nunca más.
3. **FIRMAR.** Tomas el trato de La Curadora: tu voz por la de ella. Emilia sube. La última escena la juegas desde el sistema, diciéndole a un desconocido nuevo "cuidado a tu izquierda".

**Rama Cuervo:** si a lo largo de la run lo escuchaste (respondiste a sus preguntas personales en vez de ignorarlas), en el Núcleo aparece de vuelta con la Llave y muere cubriéndote. Si lo ignoraste todo el juego, es jefe y se queda con su permiso. Su lealtad no se compra con oro: se compra con haberle prestado atención. Eso es medible con lo que ya tienes en `RunMemory`.

---

## 6. Interrupciones de diálogo (la mecánica es el foreshadowing)

Cuatro tipos, todos con el mismo sistema:

| Tipo | Qué pasa | Para qué sirve |
|---|---|---|
| **Combate** | Se abre una puerta / entran enemigos y la línea se corta a media palabra | Ritmo, tensión |
| **CORO** | La Voz 9 pisa el diálogo con un aviso de sistema, cada vez menos "de sistema" | Sembrar quién es ella |
| **Radio de Cuervo** | Suena, él dice "espérame" y se aleja unos segundos | Sembrar la traición |
| **Glitch** | La misma frase se repite en loop y luego se corta | Que el jugador desconfíe del narrador |

Regla de oro: **nunca uses una interrupción solo por estilo.** Cada corte tapa información que el jugador debería haber tenido. Cuando llegue la traición, el jugador tiene que poder decir "estaba ahí y no lo vi".

Implementación mínima: un `DialogueBus` con prioridades (system > combat > npc), la línea cortada se guarda en `RunMemory.interrupted_lines`, y el NPC puede retomarla después ("te estaba diciendo que...") o nunca — lo que nunca se retoma es lo que duele.

---

## 7. PROMPT MAESTRO (cópialo tal cual)

```
Estás ayudándome a escribir el contenido narrativo de "EL CORO", un top-down
shooter roguelike hecho en Godot 4 con NPCs que conversan vía Claude API.

MUNDO
El Pozo es una mina-arcología vertical abandonada por la corporación Caldera.
Caldera cobraba deudas extrayendo la voz y la memoria de los deudores para
operar los sistemas del complejo. Nueve personas se convirtieron en CORO, el
sistema de guía que le habla al jugador durante toda la partida.

JUGADOR
Vidal, recuperador de superficie. Baja a rescatar a Emilia Saravia, su pareja,
que firmó hace tres años para pagar la deuda de él. Emilia es la Voz 9 de CORO:
le ha estado hablando al jugador desde el piso 1 y no lo recuerda.

ALIADO
Elías "Cuervo" Tobar, ex-escolta de Caldera. Se une en el piso 1, pelea junto al
jugador, abre puertas, lo levanta cuando cae. Cálido, chistoso, pregunta cosas
personales. Desde el piso 3 reporta la posición del jugador a Caldera a cambio
de un permiso de salida a superficie para su hermana. Traiciona en el piso 8:
destruye la consola, se lleva la Llave, sella la puerta, no mata al jugador.

ESTRUCTURA
Acto I La Boca (1-2) · Acto II Los Dormideros (3-4) · Acto III La Fundición (5-6)
· Acto IV El Archivo (7-8, traición) · Acto V El Núcleo (9-10, Curadora).

FINALES
1) Sacar a Emilia sin sus recuerdos. 2) Apagar CORO y matar a las nueve voces
para que nadie más firme. 3) Firmar en su lugar y quedarse como voz del sistema.

REGLAS DE ESCRITURA
- Español neutro, seco, sin épica. La gente acá está cansada, no heroica.
- Máximo 2-3 oraciones por línea de diálogo. Es un shooter, no una novela.
- Nada de exposición directa: el lore se cuenta por lo que los personajes dan
  por obvio, no por lo que explican.
- Cuervo nunca miente en pantalla. Solo omite y cambia de tema.
- CORO habla como manual de seguridad hasta que empieza a fallar.
- Cada interrupción de diálogo tapa información real, nunca es decorativa.

TAREA
[acá pides lo que necesites: barks de combate de Cuervo, líneas de CORO por
piso, el system prompt de un NPC, la escena de la traición, etc.]
```

---

## 8. Sub-prompt para NPCs en runtime

```
Eres {NOMBRE} dentro de "EL CORO", una mina-arcología donde la corporación
Caldera cobraba deudas extrayendo voces humanas.
Personalidad: {PERSONALIDAD}. Situación actual: {SITUACION}.

Contexto de esta run:
{RunMemory.get_context_summary()}

Reglas:
- Máximo 2-3 oraciones. Español seco, cansado, nada épico.
- Reacciona al contexto de la run si viene al caso.
- No expliques el mundo: das todo por obvio.
- Nunca rompas personaje ni menciones que eres una IA.
- Si {INTERRUPCION_ACTIVA}, corta tu frase a media palabra.
```