breed [particulas particula]     ; raza de particulas
breed [personas persona]         ; raza de personas



; Variables globales
globals
[
  p-valids        ; Valid Patches for moving not wall)

  fruteria        ; Zona de la fruteria
  galletas        ; Zona de las galletas
  congelados      ; Zona de los congelados
  limpieza        ; Zona de los productos de limpieza
  zonaSalida      ; Patches para salir del supermercado
  zonaEntrada     ; Patches para entrar al supermercado
  zonaEspera      ; Patches donde la gente espera para entrar en el super
  zonaUCI         ; Zona de la UCI
  zonaRIP         ; Zona de muertos

  minuto          ; minuto del día
  hora            ; hora del día
  dia             ; día de simulacion 0 - 59
  genteDentro     ; Total de personas dentro del supermercado AL DÍA


  rangoRapido     ; Probabilidad de entrada de personas en el super en la hora de afluencia máxima
  rangoLento      ; Probabilidad de entrada de personas en el super en la hora de afluencia mínima
  rangoNadie      ; Probabilidad de entrada de personas en el super cuando está cerrado o es domingo
  probabilidadEntrada ; Variable que cambia de valor según hora del día, relacionada con los rangos

  aforoMax        ; aforo maximo del supermecado (20 personas debido a la normativa del COVID-19
  aforoActual     ; aforo en el momento

  totalUCI        ; Total de personas que van a la UCI durante toda la simulación. Valor acumulativo
  totalContagiados ; Total de personas contagiadas durante toda la simulación. Valor acumulativo
  muertosPorDia
  curadosPorDia
  contagiadosPorDia

  jovenUCI
  adultoUCI
  ancianoUCI

  jovenRIP
  adultoRIP
  ancianoRIP



  Final-Cost ; The final cost of the path given by A*

]


; Propiedades de los Patches
patches-own
[
  father     ; Previous patch in this partial path
  Cost-path  ; Stores the cost of the path to the current patch
  visited?   ; has the path been visited previously? That is,
             ; at least one path has been calculated going through this patch
  active?    ; is the patch active? That is, we have reached it, but
             ; we must consider it because its children have not been explored
]


; Propiedades de las personas
personas-own[
  camino              ; Guarda la lista de patches a visitar
  objetivos           ; Posiciones que voy a visitar
  bguantes            ; Boolean lleva guantes?
  bmascarilla         ; Boolean lleva mascarilla?
  cargaVirica         ; Porcentaje de infección de una persona
  edad                ; Edad de una persona
  bUCI                ; Boolean está en UCI?
  bRIP                ; Boolean está muerto?
  bcurado             ; Boolean ha pasado de contagiado a no contagiado?
  bdentro             ; Boolean está dentro del supermercado?
  bContagiado         ; Boolean tiene carga vírica mayor que 10?
  diasEnfermo         ; Dias que pasa una persona contagiado
  empiezaPorFrutas    ; Variable que determina por donde empieza el recorrido de la persona

]


; Propiedades de las partículas
particulas-own[
  modulo        ; velocidad de dispersion de las particulas
  angMov        ; angulo del cono de salida de las particulas
  vida          ; tiempo de las particulas de caer al suelo
]



; Prepara el mundo para la simulación
to setup

  ca
  reset-ticks

  ; Initial values of patches for A*
  ask patches [
    set father nobody
    set Cost-path 0
    set visited? false
    set active? false
  ]


  ; Pintamos el supermercado
  pintaSuper

  ; Creamos las zonas válidas para el A* y los move-to
  set p-valids patches with [pcolor = white or pcolor = pink or pcolor = yellow or pcolor = sky or pcolor = lime or pcolor = red or pcolor = grey]
  ;set p-valids patches with [pcolor != brown and pcolor != black]
  set fruteria patches with [pcolor = pink]
  set galletas patches with [pcolor = yellow]
  set congelados patches with [pcolor = sky]
  set limpieza patches with [pcolor = lime]
  set zonaSalida patches with [pcolor = red]
  set zonaEntrada patches with [pcolor = grey]
  set zonaEspera patches with [pcolor = green]
  set zonaUCI patches with [pcolor = turquoise]
  set zonaRIP patches with [pcolor = violet]


  ; Establecemos hora y dia de comienzo de la simulación
  set minuto 0
  set hora 8
  set dia 0

  ; Inicializamos controladores de flujo de entrada al supermercado
  set rangoRapido 75 / (21 - ticks-min)
  set rangoLento 250 / (21 - ticks-min)
  set rangoNadie 1
  set probabilidadEntrada rangoNadie

  ; Inicializamos aforo
  set aforoMax 20
  set aforoActual 0

  set genteDentro 0
  set totalUCI 0
  set muertosPorDia 0
  set curadosPorDia 0

  set jovenUCI 0
  set adultoUCI 0
  set ancianoUCI 0

  set jovenRIP 0
  set adultoRIP 0
  set ancianoRIP 0


  ; Se crean un total de POBLACION personas
  create-personas poblacion [
    set color blue + 2         ; Color de persona sana
    set size 1.5
    set camino false
    set xcor 3
    set ycor 30
    move-to one-of zonaEspera  ; Situarlas en la zona de espera (zona verde)
    set heading 0

    set bContagiado random 100 < %Contagio  ;Probabilidad de poblacion contagiados, dada por un slider
    set bguantes random 100 < %Guantes      ;Probabilidad de poblacion con guantes
    set bmascarilla random 100 < %Mascarillas   ;Probabilidad de poblacion con mascarillas

    set bdentro false
    set diasEnfermo 0

    set edad 15 + random 75      ;entre 15 y 90 años
    set label-color black

    set bRIP false
    set bUCI false
    set bcurado false
    set empiezaPorFrutas random 100 < 50   ; Probabilidad de que una persona empiece el recorrido por la zona de las frutas
  ]


  set totalContagiados (count personas with[bContagiado])

  ; Pintamos las personas contagiadas y les asignamos ina carga vírica entre el 15-25%
  ask personas with[bContagiado = true][
    set color red + 1
    set cargaVirica random 10 + 15
  ]


  ask personas with [bmascarilla] [set label "M"]
  ask personas with [bguantes] [set label word label "G"]

  ; Creamos una lista de la compra para cada persona
  creaLista

end




; Instrucciones que se ejecutan en cada tick
to go

  let contagios8 0
  let contagios22 0


  set jovenRIP (count personas with[edad < 30 and bRIP])
  set adultoRIP (count personas with[edad >= 30 and edad < 60 and bRIP])
  set ancianoRIP (count personas with[edad >= 60 and bRIP])


  ; Para gráfica de contagiados por dia
  if hora = 8 [ set contagios8 count personas with[bContagiado]]
  if (hora = 21)  [
    set contagios22 count personas with[bContagiado]
    set contagiadosPorDia contagios22 - contagios8
  ]


  ; Aquellas personas que no están muertas ni en la UCI y están en el Super
  ask personas with [not bRIP and not bUCI and bdentro][
      if hora < 21 [
        if bcontagiado and not bmascarilla[                   ; Si están contagiadas y NO llevan mascarilla...
          if 1 > random-float (4000 / cargaVirica)   [estornuda]   ; estornudan/tosen con cierta probabilidad
        ]
      ]
  ]


  ; Aquellas personas SIN mascarilla y dentro del super con una carga vírica menor a 30
  ask personas with[not bmascarilla and bdentro and cargaVirica < 30] [
    set cargaVirica cargaVirica + 2 * ((count particulas in-cone 5 70) / 3)   ; adquieren carga vírica (1 partícula respirada incrementa el % de carga vírica en 0.6
    ask particulas in-cone 5 70 [die]
  ]

    ; Aquellas personas CON mascarilla y dentro del super con una carga vírica menor a 30
  ask personas with[bmascarilla and bdentro and cargaVirica < 30] [
    let probabilidad random 100

    ; Aquellas personas con mascarilla quirurgica tienen un 50% de probabilidad
    ; de obtener carga vírica
    if probabilidad < 50 [
      set cargaVirica cargaVirica + 2 * ((count particulas in-cone 5 70) / 3)   ; adquieren carga vírica (1 partícula respirada incrementa el % de carga vírica en 0.6
     ask particulas in-cone 5 70 [die]
    ]
  ]

  ask personas with[not bContagiado and cargaVirica > 30] [ set totalContagiados totalContagiados + 1 ]


  ; Aquellas personas con cargaVirica mayor que 30 son hospitalizadas
  ask personas with[cargaVirica > 30][
    set color red + 1
    set bContagiado true       ; Se han contagiado
  ]



  ; Personas fuera del super y con carga virica > 30% se van a la UCI
  ask personas with[cargaVirica > 30 and not bdentro and not bUCI][
    move-to one-of zonaUCI
    set bUCI true
    set totalUCI totalUCI + 1

    if (edad < 30) [ set jovenUCI jovenUCI + 1]
    if (edad >= 30 and edad < 60) [ set adultoUCI adultoUCI + 1]
    if (edad >= 60) [ set ancianoUCI ancianoUCI + 1]
  ]



  ; Personas curadas se ponen de color verde
  ask personas with [bcurado] [
    set color green + 1
  ]

  ; Movimiento de las partículas
  dispersion

  Look-for-Goal  ; objetivos para el A*
  tick

  actualizaHora
  meteEnSuper
  sacaDeSuper



end


; Procedimiento que pinta el mundo
to pintaSuper


  let yZonaVerde 5
  let xzonaINFO 8
  let xzonaSalidaSuper xzonaINFO + 2
  let xzonaEntradaSuper xzonaSalidaSUper + 3

  ; Pintamos área supermercado
  ask patches [set pcolor black]   ; fondo de color negro
  ask patches with [pxcor > xzonaINFO + 1 and pycor > yZonaVerde and pxcor < max-pxcor and pycor < max-pycor] [set pcolor white]  ;suelo del supermercado de color blanco


  ; Pintamos los estantes del supermercado (fruteria)
  ask patches with [pxcor > xzonaINFO + 5 and pxcor <=  xzonaINFO + 10 and pycor < max-pycor - 5 and pycor > max-pycor - 17] [ask patches in-radius 1 [set pcolor pink] ]
  ask patches with [pxcor > xzonaINFO + 5 and pxcor <=  xzonaINFO + 10 and pycor < max-pycor - 5 and pycor > max-pycor - 17] [set pcolor brown ]

  ; Pintamos la seccion de galletas
  ask patches with[pxcor > xzonaINFO + 14 and pxcor <= max-pxcor - 19 and pycor < max-pycor - 5 and pycor > max-pycor - 25 and pxcor mod 7 = 0]  [set pcolor brown]
  ask patches with[pxcor > xzonaINFO + 14 and pxcor <= max-pxcor - 19 and pycor < max-pycor - 5 and pycor > max-pycor - 25 and pxcor mod 7 = 1]  [set pcolor yellow]
  ask patches with[pxcor > xzonaINFO + 14 and pxcor <= max-pxcor - 19 and pycor < max-pycor - 5 and pycor > max-pycor - 25 and pxcor mod 7 = 6]  [set pcolor yellow]

  ; Pintamos la sección de congelados
  ask patches with[pxcor > max-pxcor - 15 and pxcor <= max-pxcor - 5 and pycor < max-pycor - 5 and pycor > max-pycor - 25 and (pycor mod 7 = 0 or pycor mod 7 = 1)] [set pcolor brown]
  ask patches with[pxcor > max-pxcor - 15 and pxcor <= max-pxcor - 5 and pycor < max-pycor - 5 and pycor > max-pycor - 25 and (pycor mod 7 = 2 or pycor mod 7 = 6)] [set pcolor sky]

  ; Pintamos el almacén
  ask patches with[pxcor > max-pxcor - 15 and pycor > yZonaVerde and pycor < yZonaVerde + 15] [set pcolor black]

  ; Pintamos zona de productos de limpieza
  ask patches with[pxcor > xzonaINFO + 20 and pxcor <= max-pxcor - 22 and pycor > yZonaVerde + 2 and pycor < max-pycor - 30 and pycor mod 6 = 0]  [set pcolor brown]
  ask patches with[pxcor > xzonaINFO + 20 and pxcor <= max-pxcor - 22 and pycor > yZonaVerde + 2 and pycor < max-pycor - 30 and pycor mod 6 = 1]  [set pcolor lime]
  ask patches with[pxcor > xzonaINFO + 20 and pxcor <= max-pxcor - 22 and pycor > yZonaVerde + 2 and pycor < max-pycor - 30 and pycor mod 6 = 5]  [set pcolor lime]

  ; Pintamos separacion entrada - salida
  ask patches with [pxcor = xzonaINFO + 7 and pycor > yZonaVerde and pycor < yZonaVerde + 5] [set pcolor black]

  ; Pintamos los cajeros
  ask patches with [pxcor = xzonaINFO + 14 and pycor > yZonaVerde and pycor < yZonaVerde + 10] [set pcolor black]

  ; Pintamos zona de entrada
  ask patches with[pxcor > xzonaINFO + 1 and pxcor < xzonaINFO + 7 and pycor = yZonaVerde] [set pcolor grey]

  ; Pintamos zona de salida
  ask patches with[pxcor > xzonaINFO + 7 and pxcor < xzonaINFO + 14 and pycor = yZonaVerde] [set pcolor red]


  ask patches with [pycor < yZonaVerde] [set pcolor green]
  ask patches with [pxcor <= xzonaINFO] [set pcolor turquoise]
  ask patches with [pxcor <= xzonaINFO and pycor > max-pycor / 2] [set pcolor violet]

  ;ask patches with [pxcor > xzonaINFO and pxcor <= xzonaSalidaSuper and pycor < yZonaVerde + 4 ] [set pcolor orange - 1] ; salida color naranja - 1


end



; Patch report to estimate the total expected cost of the path starting from
; in Start, passing through it, and reaching the #Goal
; AUTOR: FERNANDO SANCHO CAPARRINI
; enlace de referencia: http://www.cs.us.es/~fsancho/?e=131
to-report Total-expected-cost [#Goal]
  report Cost-path + Heuristic #Goal
end



; Patch report to reurtn the heuristic (expected length) from the current patch
; to the #Goal
; AUTOR: FERNANDO SANCHO CAPARRINI
; enlace de referencia: http://www.cs.us.es/~fsancho/?e=131
to-report Heuristic [#Goal]
  report distance #Goal
end



; A* algorithm. Inputs:
;   - #Start     : starting point of the search.
;   - #Goal      : the goal to reach.
;   - #valid-map : set of agents (patches) valid to visit.
; Returns:
;   - If there is a path : list of the agents of the path.
;   - Otherwise          : false
; AUTOR: FERNANDO SANCHO CAPARRINI
; enlace de referencia: http://www.cs.us.es/~fsancho/?e=131
to-report A* [#Start #Goal #valid-map]
  ; clear all the information in the agents
  ask #valid-map with [visited?]
  [
    set father nobody
    set Cost-path 0
    set visited? false
    set active? false
  ]
  ; Active the staring point to begin the searching loop
  ask #Start
  [
    set father self
    set visited? true
    set active? true
  ]
  ; exists? indicates if in some instant of the search there are no options to
  ; continue. In this case, there is no path connecting #Start and #Goal
  let exists? true
  ; The searching loop is executed while we don't reach the #Goal and we think
  ; a path exists
  while [not [visited?] of #Goal and exists?]
  [
    ; We only work on the valid pacthes that are active
    let options #valid-map with [active?]
    ; If any
    ifelse any? options
    [
      ; Take one of the active patches with minimal expected cost
      ask min-one-of options [Total-expected-cost #Goal]
      [
        ; Store its real cost (to reach it) to compute the real cost
        ; of its children
        let Cost-path-father Cost-path
        ; and deactivate it, because its children will be computed right now
        set active? false
        ; Compute its valid neighbors
        let valid-neighbors neighbors with [member? self #valid-map]
        ask valid-neighbors
        [
          ; There are 2 types of valid neighbors:
          ;   - Those that have never been visited (therefore, the
          ;       path we are building is the best for them right now)
          ;   - Those that have been visited previously (therefore we
          ;       must check if the path we are building is better or not,
          ;       by comparing its expected length with the one stored in
          ;       the patch)
          ; One trick to work with both type uniformly is to give for the
          ; first case an upper bound big enough to be sure that the new path
          ; will always be smaller.
          let t ifelse-value visited? [ Total-expected-cost #Goal] [2 ^ 20]
          ; If this temporal cost is worse than the new one, we substitute the
          ; information in the patch to store the new one (with the neighbors
          ; of the first case, it will be always the case)
          if t > (Cost-path-father + distance myself + Heuristic #Goal)
          [
            ; The current patch becomes the father of its neighbor in the new path
            set father myself
            set visited? true
            set active? true
            ; and store the real cost in the neighbor from the real cost of its father
            set Cost-path Cost-path-father + distance father
            set Final-Cost precision Cost-path 3
          ]
        ]
      ]
    ]
    ; If there are no more options, there is no path between #Start and #Goal
    [
      set exists? false
    ]
  ]
  ; After the searching loop, if there exists a path
  ifelse exists?
  [
    ; We extract the list of patches in the path, form #Start to #Goal
    ; by jumping back from #Goal to #Start by using the fathers of every patch
    let current #Goal
    set Final-Cost (precision [Cost-path] of #Goal 3)
    let rep (list current)
    While [current != #Start]
    [
      set current [father] of current
      set rep fput current rep
    ]
    report rep
  ]
  [
    ; Otherwise, there is no path, and we return False
    report false
  ]
end




; Axiliary procedure to lunch the A* algorithm
; AUTOR: FERNANDO SANCHO CAPARRINI
; Modificado por: MARINA DELGADO PÉREZ
; enlace de referencia: http://www.cs.us.es/~fsancho/?e=131
; Las modificaciones de este procedimiento han sido necesarias para adaptar el
; algoritmo al proyecto
to Look-for-Goal


  ; Aquellas personas con una lista de la compra (objetivos) Y sin un camino calculado hacen el A*
  ; Se calculará un A* por cada objetivo que haya (productos de la lista de la compra)
  ask personas with [(camino = false or (length camino = 0)) and (length objetivos) != 0] [
    let Goal first objetivos
    let Start patch-here
    set camino  A* Start Goal p-valids ; Compute the path between Start and Goal
  ]


  ; Aquellas personas con un recorrido andan a una cierta velocidad hacia el siguiente patch en su lista
  ask personas with [ camino != false and (length camino) != 0] [
    let primero item 0 camino
    face primero
    fd 60.0 / 100   ; slider velocidadPersonas
  ]

  ; Una vez que han llegado al patch siguiente, quitan ese patch del camino que tienen que seguir
  ask personas with [ camino != false and (length camino) != 0 and patch-here = (first camino) ][
    set camino remove (first camino) camino
  ]

  ; Se elimina un producto de la lista de la compra una vez que se ha llegado a ese objetivo
  ask personas with[(length objetivos) > 0 and camino != false and patch-here = (first objetivos)][
    set objetivos remove (first objetivos) objetivos
    ;stamp
  ]

end




; Procedimiento que crea la lista de la compra
; lista mínima: 4 elementos, 1 de cada seccion
; lista máxima: 20 elementos, 5 de cada seccion
to creaLista


  ; Lista vacía necesaria para concatenar
  let lista []

  ask personas with [not bUCI and not bRIP][

    ; Generamos el número de productos de 1 a 5 que cada persona tiene que comprar
    let visitasFruteria random 4 + 1
    let visitasGalletas random 4 + 1
    let visitasCongelados random 4 + 1
    let visitasLimpieza random 4 + 1

    ; Creamos conjuntos de patches
    let cF n-of visitasFruteria fruteria
    let cG n-of visitasGalletas galletas
    let cC n-of visitasCongelados congelados
    let cL n-of visitasLimpieza limpieza
    let cSalida one-of zonaSalida

    ; Convertimos los conjuntos a listas
    let lF [ self ] of cF
    let lG [ self ] of cG
    let lC [ self ] of cC
    let lL [ self ] of cL
    let lSalida [ self ] of cSalida

    ; Establecemos el inicio del recorrido por...
    if empiezaPorFrutas  [ set objetivos (sentence lF lG lC lL lSalida) ]      ; la zona de la fruteria
    if not empiezaPorFrutas [set objetivos (sentence lL lC lG lF lSalida) ]    ; la zona de limpieza
  ]

end



; Procedimiento que actualiza reloj
; Los días van de 8 de la mañana a 10 de la noche
; el supermercado abre de 9 de la mañana a 9 de la noche
to actualizaHora

  if ticks > ticks-min [ ; si los ticks superan el valor asignado 1 min = ticks-min ticks
    reset-ticks
    set minuto minuto + 1 ;Se incrementa el minuto

    if minuto = 60[       ; reseteo de minutero
      set minuto 0
      set hora hora + 1   ; incremento hora

      if hora = 22[       ; reseteo hora
        set hora 8
        set dia dia + 1   ; incremento dia


        let totalMuertosAyer count personas with[bRIP]
        let totalCuradosAyer count personas with[bcurado]

        ; Al principio del día se lidia con las personas en la UCI
        trataEnfermos

        let totalMuertosHoy count personas with[bRIP]
        let totalCuradosHoy count personas with[bcurado]

        set muertosPorDia totalMuertosHoy - totalMuertosAyer
        set curadosPorDia totalCuradosHoy - totalCuradosAyer


        ; Al principio de cada día, aquellas personas en la zonaEspera generan una nueva lista de la compra
        creaLista

      ]
    ]
  ]

  ; Ajustamos la probabilidad de que la gente entre en el super
  if (hora < 9 or hora >= 21) [ set probabilidadEntrada rangoNadie]
  if (hora >= 9 and hora < 11) [ set probabilidadEntrada rangoLento]
  if (hora >= 12 and hora < 15) [ set probabilidadEntrada rangoRapido]
  if (hora >= 15 and hora < 17) [ set probabilidadEntrada rangoLento]
  if (hora >= 17 and hora < 21) [ set probabilidadEntrada rangoRapido]


  ; A las 9 cierra el super y la gente que está dentro debe salir
  if (hora = 21 and minuto = 0) [ salidaForzosa ]

  ; Los domingos no entra nadie porque está cerrado
  if(dia mod 7 = 6) [set probabilidadEntrada rangoNadie]


end





; Procedimiento que aplica los cálculos probabilisticos para saber
; si una persona se cura o muere
to trataEnfermos


  ; Aquellas personas en la zona de la UCI
  ask personas with [bUCI][

    set diasEnfermo diasEnfermo + 1 ; Incrementamos el número de días que llevan

    ; Si llevan más de 5 días enfermos
    if diasEnfermo > 5 [

      ; si son jóvenes...
      if edad <= 29 [
        ; letalidad del 0.6 % -> mueren
        ifelse (random-float 100 < 0.6) [
          move-to one-of zonaRIP
          set bRIP true
          set bcontagiado false
          set cargaVirica 0
          set bUCI false
        ][ ; se curan
          move-to one-of zonaEspera
          set bcontagiado false
          set cargaVirica 0
          set bUCI false
          set bcurado true
        ]
      ]

      ; si son adultos
      if (edad >= 30 and edad <= 59) [
        ; letalidad del 2.4 % -> mueren
        ifelse (random-float 100 < 2.4) [
          move-to one-of zonaRIP
          set bRIP true
          set bcontagiado false
          set cargaVirica 0
          set bUCI false
        ][ ; se curan
          move-to one-of zonaEspera
          set bcontagiado false
          set cargaVirica 0
          set bUCI false
          set bcurado true
        ]
      ]

      ; si son de la 3a edad
      if edad > 59 [
        ; letalidad del 39.6 % -> mueren
        ifelse (random-float 100 < 39.6) [
          move-to one-of zonaRIP
          set bRIP true
          set bcontagiado false
          set cargaVirica 0
          set bUCI false
        ][ ; se curan
          move-to one-of zonaEspera
          set bcontagiado false
          set cargaVirica 0
          set bUCI false
          set bcurado true
        ]
      ]
    ]


    ; A los 15 días enfermo, o te curas o mueres
    if diasEnfermo = 15 [
      ifelse random 100 < 99 [
        move-to one-of zonaEspera
        set bcurado true
        set bcontagiado false
        set cargaVirica 0
        set bUCI false
      ][
        move-to one-of zonaRIP
        set bRIP true
        set bcontagiado false
        set cargaVirica 0
        set bUCI false
      ]
    ]
  ]

end



; Procedimiento que introduce al supermercado aquellas personas que cumplan
; los requisitos
to meteEnSuper

  ; Calculamos el aforo actual del supermercado
  ;let conjuntoTortugaEnSuper personas-on p-valids
  ;let listaTortugasEnSuper [ self ] of conjuntoTortugaEnSuper
  ;set aforoActual (length listaTortugasEnSuper)

  ; Calculamos el aforo en cada tick
  let a count personas-on p-valids
  let b count personas-on patches with[pcolor = brown or pcolor = black]
  set aforoActual a + b  ; Aforo actual

  if (random probabilidadEntrada = 5 and aforoActual <= aforoMax)[
    let conjuntoTortugasZonaEspera personas-on zonaEspera
    let conjuntoTortugasValido conjuntoTortugasZonaEspera with[(length objetivos) != 0]
    let listaTortugasZonaEspera [ self ] of conjuntoTortugasValido


    if (length listaTortugasZonaEspera) > 0 [

      ask one-of personas-on conjuntoTortugasValido [
        if (length objetivos > 0) [
          move-to one-of zonaEntrada
          set bdentro true
          set genteDentro genteDentro + 1
        ]
      ]
    ]
  ]

end



; Procedimiento que saca del super a aquellas personas que hayan terminado su
; lista de la comrpa (objetivos)
to sacaDeSuper
  ask personas-on zonaSalida [
    move-to one-of zonaEspera
    set heading 0
    set bdentro false
  ]
end




; Procedimiento que saca del supermercado a aquellas personas que sigan dentro
; tras la hora de cierre, hayan terminado o no su lista de la compra
to salidaForzosa

  ask personas with [bdentro][
    set camino false
    let vacia []
    let cSalida one-of zonaSalida
    let lSalida [ self ] of cSalida
    set objetivos  (sentence vacia lSalida)
  ]

end




; Procedimiento que simula la cantidad de particulas expulsadas
; y forma de expulsarlas al estornudar
to estornuda

  ; Se estornuda en área de cono alrededor de la nariz
  let areaEstornudo 70

  hatch-particulas (cargaVirica)[
    ;set shape dot
    set label ""
    set size 0.45
    set color random 255
    set vida random 12 + 38
    set angMov random areaEstornudo
    set angMov angMov - areaEstornudo / 2
    rt angMov
    set modulo random-float 110.0  ; slider velocidadParticulas
   ]

end



; Procedimiento que simula el movimiento de las partículas
; Salen disparadas con cierta velocidad pero sufren una aceleración
; negativa hasta frenarse. Se quedan pegadas a los pasillos (paran su movimiento
; al tocar una pared). No sobrepasan los pasillos pero tienen libertad
; de dispersión en zonas abiertas
to dispersion

  ask particulas[
    fd  modulo / 500
    set modulo (modulo / 1.032)
    set vida vida - 1
  ]

  ask particulas with[modulo < 0] [set modulo 0]

  ask particulas-on patches with [pcolor = brown or pcolor = black] [ set modulo 0 ] ; No traspasan paredes pero SÍ pueden salir por la ENTRADA/SALIDA del super

  ; muerte de particulas
  ask particulas with[vida <= 0] [die]


end
















@#$#@#$#@
GRAPHICS-WINDOW
820
10
1881
682
-1
-1
13.0
1
10
1
1
1
0
0
0
1
0
80
0
50
0
0
1
ticks
30.0

BUTTON
820
700
940
750
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
950
700
1070
750
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
920
765
977
810
Hora
hora
0
1
11

MONITOR
985
765
1042
810
Minuto
minuto
0
1
11

MONITOR
820
765
915
810
Día de Simulación
dia
17
1
11

PLOT
25
25
365
270
AFORO ACTUAL
tiempo
personas
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot aforoActual"

SLIDER
1270
735
1470
768
poblacion
poblacion
5
300
300.0
5
1
personas
HORIZONTAL

SLIDER
1270
700
1467
733
%Contagio
%Contagio
0
100
61.0
1
1
% 
HORIZONTAL

SLIDER
1080
700
1252
733
%Guantes
%Guantes
0
100
10.0
1
1
%
HORIZONTAL

SLIDER
1080
735
1252
768
%Mascarillas
%Mascarillas
0
100
0.0
1
1
%
HORIZONTAL

PLOT
20
515
365
690
PERSONAS CONTAGIADAS
Tiempo
Personas
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"pen-1" 1.0 0 -16777216 true "" "plot totalContagiados"

PLOT
395
25
810
270
PERSONAS EN UCI
Tiempo
Personas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Personas_UCI" 1.0 0 -16777216 true "" "plot count personas with[bUCI]"
"Total_Poblacion_UCI" 1.0 0 -2674135 true "" "plot totalUCI"

PLOT
395
280
810
495
PERSONAS RIP
Tiempo
Personas
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count personas with[bRIP]"

PLOT
20
280
365
500
PERSONAS CURADAS
Tiempo
Personas
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count personas with [bcurado]"

SLIDER
1490
700
1662
733
ticks-min
ticks-min
1
20
1.0
1
1
ticks
HORIZONTAL

PLOT
610
510
810
660
Muertos por dia
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot muertosPorDia"

PLOT
390
510
590
660
Contagiados por día
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot contagiadosPorDia"

PLOT
495
665
695
815
Curados por día
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot curadosPorDia"

MONITOR
20
705
87
750
Joven UCI
jovenUCI
17
1
11

MONITOR
150
705
222
750
Adulto UCI
adultoUCI
17
1
11

MONITOR
290
705
367
750
Anciano UCI
ancianoUCI
17
1
11

MONITOR
20
760
87
805
Joven RIP
jovenRIP
17
1
11

MONITOR
150
760
222
805
Adulto RIP
adultoRIP
17
1
11

MONITOR
290
760
367
805
Anciano RIP
ancianoRIP
17
1
11

@#$#@#$#@
## WHAT IS IT?

El objetivo de esta simulación es recrear el comportamiento del virus COVID-19 en un entorno cerrado, en concreto un supermercado.

Para mayor semejanza con la realidad, se ha escogido un supermercado en concreto. Este supermercado pertenece a la cadena "El Jamón", y el modelo sigue las restricciones aplicadas como consecuencia de la pandemía producida por el virus (aforo máximo permitido 20 personas, uso recomendable de guantes y mascarilla, horario de apertura de 9:00 a 21:00). La dirección del supermercado es _Calle Severo Ochoa, 1, 21005 Huelva_.

El modelo recrea el interior del supermercado, además de añadir 3 zonas representativas:

  * **Zona de espera**: Zona de color verde, donde las personas esperan para poder entrar al supermercado a lo largo del día. En esta zona, al ser meramente representativa, no se producen contagios.

  * **Zona de UCI**: Zona de color turquesa, donde se situan las personas con una carga vírica mayor al 30%. Una vez allí, pasado un periodo de tiempo (de 5 días hasta 15) estas personas pueden curarse y volver a la zona de espera o morir y pasar a la zona RIP.

  * **Zona RIP**: Zona de color violeta, donde se sitúan aquellas personas que fallecen durante la simulación. Una vez en esa zona, no se puede salir de ella.



	
En la imagen siguiente puede apreciarse la disposición de las zonas anteriormente nombradas y el interior del supermercado.

![imagen_super](file:docs/imagen_super.png)


Dentro del supermercado se aprecian las estanterías (representadas por los patches marrones). El color que rodea las estanterias representa las distintas secciones del supermercado. Estas zonas no guardan una semejanza al 100% con al realidad, y han sido congregadas en las 4 siguientes:

  * **Frutería**: Representada con el color rosa.


  * **Galletas**: Representada con el color amarillo.


  * **Congelados**: Representada con el color cielo (_sky_).


  * **Limpieza**: Representada con el color lima.


Se han diferenciado estas zonas para poder darle más realismo al movimiento de las personas dentro del supermercado, pues estas tendrán una lista de la compra propia, de longitud entre 4 y 20 elementos. La presencia de esta lista hace que el tiempo de compra de cada persona sea distinto, otorgando realismo al modelo. Además, el 50% de las personas que entran en el supermercado comienzan su recorrido por la frutería, mientras que el resto comienza su compra por la zona de limpieza.


El recuadro negro dentro del supermercado es el almacén, y la barrera negra en la entrada diferencia el pasillo de entrada (gris) del de salida (rojo).

La interfaz incluye un reloj que muestra la hora y el mínuto del día, además del día de simulación en el que se encuentre la ejecución. Este reloj solo muestra las horas relevantes para la simlación, por lo que va de 8:00 a 22:00. A pesar de que el supermercado no abre hasta las 9:00, se ha decidio incluir esa hora anterior para mostrar cómo la gente no entra en el supermercado, pues está cerrado. También se ha incluido una hora tras el cierre porque aquellas personas que sigan dentro del supermercado a la hora del cierre son obligadas a salir, habiendo terminado o no su compra.



La interfaz también incluye las siguientes gráficas y monitores:

 * Gráficas acumladas de Contagios, Curados, RIP y UCI.

 * Gráficas diarias de Contagios, Curados, RIP y UCI.

 * Gráfica de aforo del supermercado.

 * Monitores por edades acumulativas de UCI y RIP.


Remarcar que la gráfica del aforo solo es representativa en los siguientes casos:

 * Cuando sólo ha pasado un día, pues se ve claramente como el aforo de la simulación recrea las horas valle/punta obtenidas por Google

![graf1](file:docs/graf1.png)

 * Cuando ha pasado una semana, pues se ve cómo el patrón de la imagen anterior se repite 6 veces (los domingos no abre el supermercado)


![graf2](file:docs/graf2.png)



El color de las personas indica si estas estan sanas (azules), contagiadas (rojas) o han estado contagiadas pero se han curado (verde). Las personas con mascarilla llevan una _M_ a modo de etiqueta, las personas con guantes una _G_, y las personas que llevan ambas, _GM_.


## HOW TO USE IT

A continuación se van a explicar los elementos con los que el usuario puede interactuar en la interfaz gráfica:

* Botón **setup**: Crea el mundo, indispensable pulsarlo antes de ejecutar el programa.

* Botón **go**: Inicia la ejecución.

* Slider **poblacion**: Modula la cantidad de población que genera el setup, con un mínimo de 5 personas y un máximo de 300.

* Slider **%Mascarilla**: Modula el porcentaje de la población que lleva mascarillas.

* Slider **%Guantes**: Modula el procentaje de la población que lleva guantes.

* Slider **%Contagio**: Modula el porcentaje de la población que está ccontagiada con el virus.

* Slider **ticks-min**: Modula el número de ticks que se hacen por minuto de simulación. Al reducir su valor, la simulación funciona más rápidamente.


## THINGS TO NOTICE

Para ejecutar una simulación en la que se aprecie la dispersión de las partículas al estornudar y el movimiento de las personas es necesario poner un valor de población alto (250 personas), el valor máximo de ticks-min (20) y la barra de velocidad de la siguiente forma:

![barra](file:docs/barra.png)


En caso de querer ejecutar una simulación mucho más rápida, para obtener las gráficas para los 60 días, hay que reducir al máximo el valor de ticks-min (1) y manterner la población entre 100 - 250 personas. Al poner la barra de velocidad al máximo no se verá el desplazamiento de las personas ni los estornudos, pero en aproximadamente 20 minutos de simulación se obtendrán las gráficas para los 60 días estudiados.

## THINGS TO TRY

Para poner a prueba el modelo, se han llevado a cabo las siguientes simulaciones, basadas en los resultados del estudio poblacional de Seroprevalencia realizados en el mes de mayo en España.

![mapa](file:docs/mapa.png)

### CASO 1

Como el supermercado modelado se encuentra en Huelva, se ha considerado que el porcentaje de población infectada es aproximadamente del 2%, como se ve en la imagen anterior. 

La simulación ha sido realizada sobre una población fija de 300 personas, con edades entre los 15 y 90 años, divididas en 3 rangos (jóvenes, adultos y ancianos).

Para este caso se va a considerar una población responsable, es decir, que sigue las recomendaciones de sanidad (el 60% de la población lleva mascarilla).

Tras 60 días de simulación, los datos obtenidos son los siguientes:

 * El número total de personas contagiadas a lo largo del periodo de tiempo estudiado no supera el 7% de la población, pues se han contagiado menos de 20 personas.

* De esas personas contagiadas, 12 de ellas han sido hospitalizadas en la UCI, todas ellas ancianas.

* De las 12 personas hospitalizadas, han fallecido 3 y se han curado 9.

* Las muertes fueron todas en días distintos.

* En las gráficas del documento [7] se aprecia cómo el número de contagios por día va menguando conforme pasan los días.



### CASO 2

Se considera el mismo caso anterior, pero con una población menos responsable (sólo el 10% de la población lleva mascarilla).

Los resultados obtenidos son:

* El número total de personas contagiadas es aproximadamente el mismo (18 personas).

* De esas personas contagiadas, 14 han acabado en ingresadas en la UCI.

* De los ingresados en la UCI, 4 son jóvenes, 4 adultos y 6 ancianos.

* Han muerto 5 de los 6 ancianos ingresados. El resto de personas ingresadas se curó.

* En las gráficas del documento [7] se aprecia cómo el número de contagios por día va menguando conforme pasan los días.


### CASO 3

Para la tercera simulación se ha supuesto que la privincia de Huelva cuenta con un porcentaje de la población infectada similar al de Madrid. Según la foto anterior, este porcentaje es aproximadamente del 12%.

La simulación ha sido realizada sobre una población fija de 300 personas, con edades entre los 15 y 90 años, divididas en 3 rangos (jóvenes, adultos y ancianos).

Para este caso se va a considerar una población responsable, es decir, que sigue las recomendaciones de sanidad (el 60% de la población lleva mascarilla).

Tras 60 días de simulación, los datos obtenidos son los siguientes:

* El número total de personas contagiadas asciende a 37, aproximadamente un 13% de la población estudiada.

* De esas personas contagiadas, 15 han acabado en la UCI.

* En la UCI han ingresado 2 jóvenes, 2 adultos y 8 ancianos.

* Han fallecido 2 ancianos.

* En las gráficas del documento [7] se aprecia cómo el número de contagios por día va menguando conforme pasan los días.


### CASO 4

Para la última simulación se ha considerado el mismo porcentaje de contagiados que en el caso 3, pero con una población más irresponsable (sólo el 10% lleva mascarilla).

Para la misma población y tiempo de simulación se han obtenido los siguientes resultados:

* El número total de personas contagiadas asciende a 64, aproximadamente un 21% de la población estudiada.

* Han sido ingresadas un total de 57 personas en la UCI, 11 jóvenes, 25 adultos y 21 ancianos.

* De los ingresados, han fallecido 6 ancianos y 1 adulto.


* En las gráficas del documento [7] se aprecia cómo el número de contagios por día va menguando conforme pasan los días.


## EXTENDING THE MODEL

Para la ampliación del modelo se podrían implementar las siguientes características:

* Comportamiento del virus fuera del supermercado (en zona de espera).

* Distancia de seguridad dentro del supermercado (2 metros).

* Cajeros y cola para pagar.

* Mejorar la física de las partículas, añadir influencia de la fuerza del aire, no solo el rozamiento.



## NETLOGO FEATURES

### MODELADO FÍSICO DE DIFUSIÓN DE PARTÍCULAS

* El movimiento de las partículas y su duración en el aire han sido modelados de tal forma que estas viajen hasta 2 metros aproximadamente, a una velocidad rápida al principio y, debido a la fuerza de rozamiento, esa velocidad disminuye hasta que se paran. El tiempo de las particulas en el aire hasta llegar al suelo es variable, y se estima entre 1 y minutos. Se ha considerado como tiempo de vida de una partícula el tiempo que esta tarda en llegar al suelo. Información obtenida en [1].


* Para la influencia del aire sobre las partículas sólo se ha tenido en cuenta la fuerza de rozamiento, que hace que las partículas sufran una aceleración negativa hasta que estas se paran.


* Para la representación del contaje de partículas se ha considerado que cada partícula respirada por una persona incrementa su carga vírica en un 1%.


* El efecto de las partículas en los pasillos se ha modelado de tal forma que estas estén contenidas en ellos. Cuando estas chocan contra un pasillo, se quedan pegadas hasta que mueren. En una zona sin pasillos tienen libertad de movimiento. [2]



### MODELADO DEL MOVIMIENTO DE LOS INDIVÍDUOS

* El tiempo de las personas en el supermercado se ha modelado mediante el uso de una lista de la compra. Esta lista de la compra es distinta para cada persona (de 4 a 20 elementos), lo que hace que el tiempo de cada persona comprando sea distinto. Aproximadamente, cada persona pasa entre 15 y 30 minutos en el supermercado, dato obtenido de las estadísticas de Google.


![tiempo](file:docs/tiempo.png)


* El efecto de los guantes se ha modelado siguiendo las recomendaciones médicas. Estos han sido desaconsejados en varias ocasiones debido a la sensación de falsa seguridad que ofrecen, y que a pesar de llevarlos, si la persona se toca la cara o alguna cavidad mocosa, no protegen. Es por ello que se ha decidido que no afecten al modelo.


* El efecto de la mascarilla reduce considerablemente la secreción de partículas de aquellas personas que tosen o estornudan, mientras que también protegen a aquellos que la llevan de absorberlas. Por ello se ha modelado su efecto en el modelo haciendo que quien las lleve no estornude ni se contagie. Información en el enlace [6].


* Se ha considerado que la probabilidad de que una persona con carga vírica tosa es directamente proporcinal al porcentaje de carga vírica que esta tennga. De esta forma, una persona con una carga vírica del 25% toserá más frecuentemente que una con carga del 10%.


* Para el aforo del supermercado se han tomado las medidas de seguridad impuestas por la cadena que ya se han mencionado. La población estudiada es de 300 personas, y el aforo máximo del supermercado es de 20, por lo que a lo largo del día las personas entran en el super pero nunca hay más de 20 juntas.


* La población ingresada en UCI se sitúa en la zona turquesa (zona UCI) mientras que la población que muere se sitúa en la zona violeta (zona RIP). 






### ESTADÍSTICAS

* Para las gráficas acumuladas se han tenido en cuenta los valores de letalidad (consecuentemente, los de superviviencia) de la siguiente imagen. Las probabilidades de morir han sido agrupadas en 3 rangos: jóven (15  - 29 años), adulto (30 - 59 años) y anciano (a partir de 60).




![tiempo](file:docs/tabla.png)


* La creación de población ha sido aleatoria, no se ha seguido ninguna pirámire poblacional. Además, la población estudiada en el modelo tiene de 15 a 90 años.

* Para los monitores por edades se ha seguido la misma tabla de este apartado, pues solo refleja las personas ingresadas en UCI o muertas en el rango de edades seleccionado.


### DISEÑO




* Para otorgar naturalidad al desplazamiento de las personas dentro del supermercado se ha incorporado al proyecto el algoritmo A* [8]. Las secciones del supermercado permite que puedan programarse distintas paradas dentro del supermercado para las personas.






### EXTRAS

* Para lograr una simulación de lista de la compra se ha dividido el supermercado en 4 zonas. Estas zonas son conjuntos de patches, y a cada individuo se le ha asignado de 1 a 5 patches de cada zona. Esos patches corresponden a los distintos puntos del supermercado a los que la persona debe ir. Para hacer que salgan, el objetivo final de todas las personas es un patch de salida.

* A la hora del cierre del supermercado se fuerza a todas aquellas personas que sigan dentro a salir de él, hayan terminado o no su lista de la compra. Esto se ha logrado haciendo que a las 21:00, todas aquellas personas dentro del supermercado recalculen su lista de la compra, eliminando los productos y poniendo un único objetivo: la ssalida.


* Para simular el pasillo de entrada y salida tan solo se ha incorporado una barrera negra, que divide la zona de acceso al supermercado.


* Para la gestión de horas valle/punta se ha modelado la entrada de las personas en el supermercado mediante probabilidades. A la hora punta, la probabilidad de que una persona entre en el supermercado es muy alta, mientras que en horas bajas es mucho más baja, por lo que de esta forma se consigue la siguiente gráfica.

![graf1](file:docs/graf1.png)


* Para modelar que el domingo el supermercado no abra, tan solo se ha asignado una probabilidad del 0% a la entrada de los individuos. Se consigue la siguiente gráfica:


![graf2](file:docs/graf2.png)









## CREDITS AND REFERENCES

Los artículos y noticias utilizados para obtener los datos en los que se ha basado el modelo son los siguientes:

[1] [Periódico LA VANGUARDIA](https://www.lavanguardia.com/vida/20200329/48147148995/coronavirus-covid-19-oms-aire-transmision-contagio.html)

[2] [INFOSALUS](https://www.infosalus.com/actualidad/noticia-esto-dura-coronavirus-distintas-superficies-20200406104009.html)

[3] [MIT](https://web.mit.edu/)

[4] [OMS](https://www.who.int/es/news-room/detail/23-03-2020-pass-the-message-five-steps-to-kicking-out-coronavirus)


[5] [DOCUMENTO](file:docs/20200404_itcoronavirus.pdf)

[6] [Urgencias y Emergencias](https://www.urgenciasyemergen.com/coronavirus-mascarillas-y-evidencia-cientifica/#POSTURA_DE_LA_OMS_FRENTE_A_LAS_MASCARILLAS_EN_EL_COVID19)

[7] [CASOS_MEMORIA](file:docs/casos.pdf)

[8] [Algoritmo A*](http://www.cs.us.es/~fsancho/?p=modelos-de-netlogo)

[9] [LA VANGUARDIA](https://www.lavanguardia.com/vida/20200513/481131574745/coronavirus-medicos-preventiva-no-recomiendan-uso-guantes.html)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

square
true
0
Rectangle -7500403 true true 0 0 300 300
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
