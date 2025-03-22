---
title: "ESPHome thermostaat voor Daikin Altherma 3"
tags: ESPHome Modbus Warmtepomp
excerpt: Een beschrijving van hoe ik een ESPHome thermostaat heb gebouwd voor de Daikin Altherma 3 warmtepomp.
---

In [een vorig artikel](/2025/daikin-altherma-3-lokaal-aansturen) keek ik naar welke manieren mijn warmtepomp lokaal aan te sturen is. Dit leverde een Modbus RTU interface op waarmee ik de gewenste functies van de warmtepomp kan aansturen. Ik dit artikel beschrijf ik hoe mijn eigen gebouwde thermostaat hiervan gebruik maakt, wat ik er mee probeer te bereiken en hoe dat werkt.

Inmiddels hangt aan de woonkamer muur een AirGradient luchtkwaliteitsmeter welke als thermostaat fungeert, in plaats van de Madoka thermostaat die met de warmtepomp kwam.
 
![](/assets/images/daikin_altherma_3/airgradient_aan_muur.jpg){: width="400" }

Ja, ik moet de stroomvoorziening nog netjes wegwerken, maar het is een mooi apparaat aan de muur. Het kan naast de temperatuur ook de luchtkwaliteit meten en heeft ledjes en een display voor nuttige informatie, niet alleen voor de luchtkwaliteit, maar ook andere meldingen vanuit Home Assistant kunnen hier als notificaties op weergegeven worden.

## Doel

Uiteraard is het super gaaf en leerzaam om zelf iets te bouwen, maar een lijst van redenen waarom je dit doet is een goed idee :P.

Na ruim een jaar de warmtepomp in gebruik te hebben, kwam ik de volgende problemen tegen die ik graag wil oplossen.

- **Verstoring gemeten temperatuur**: De Daikin thermostaat heeft een afwijking van 0,3-0,4 graden naar boven, zodra deze aanslaat. Dit komt doordat de ledjes die aan gaan bij aanslaan warm worden. Dit verstoort de meting van de thermostaat. Ik verwacht beter van een thermostaat
- **Afwezige modulatie**: De modulatie van de thermostaat werkt niet goed. Hoewel deze correct de aanvoertemperatuur aanpast gebaseerd op de huidige woonkamer temperatuur, zal hij toestaan dat de woonkamer temperatuur stijgt tot 1,5 graden boven het setpoint voordat hij afslaat. Dit is niet aan te passen. Na contact met Daikin geven zij toe dat dit niet goed werkt, en adviseren zij om modulatie te zetten. Dit maakt het effectief een aan/uit thermostaat, wat weer zorgt voor erg schommelde temperatuur in de woonkamer. Dit kan veel beter.
- **Schommelde woonkamer temperatuur**: De thermostaat heeft een hysteresis van 0,5 graden aan de boven en onder kant van de set temperatuur. Combineer dit met een correct afgestelde stooklijn die bedoeld is om de warmtepomp zo rustig mogelijk te laten draaien en dus een temperatuur aan te houden ipv dat de temperatuur stijgt, en je krijgt een schommeling van ruwweg 1,5 graden in de woonkamer over enkele dagen. Dit kan veel beter.
- **Beperkt programma**: De thermostaat is handmatig instelbaar in stappen van 0,5 graden. De planning is maar per hele graad in te stellen.
- **Efficienter gebruik van de backup heater**: Als het buiten warmer is dan 25 graden, zal de warmtepomp maximaal 45 graden water kunnen produceren met de buiten unit. Warmer water dan dat zal dan altijd met de backup-heater gemaakt worden. Deze is 2-3x zo inefficiënt als de buitenunit en wil je zo veel mogelijk voorkomen.
  - De wekelijkse desinfectie run (waarbij de tank op 60 graden wordt verwarmd) zal dus een groot deel op de backup heater draaien in de zomer. In de zomer voer je dit dus liever uit in de vroege ochtend, en in de winter op het warmst van de dag. Het moeten aanpassen van deze instelling elk seizoen is vervelend.
  - De tank continu instellen op 45 graden is onvoldoende voor ons op koudere dagen. Daarvoor heeft de warmtepomp een stooklijn voor de tank, zodat deze op koudere dagen op een hogere temperatuur aanhoudt. Dit werkt oke, behalve dat de lage buitentemperatuur maximaal 10 graden is. Dit is voor mijn usecase (2 regendouches en een groot bad) weer te laag, en wil ik graag hoger aanhouden.

Daarnaast mis ik op dit moment de volgende features:
- **Weersafhankelijke / zon sturing**: Als de zon veel schijnt, hoeft de verwarming niet zo hard te werken. Moduleer hem dan terug.
- **Openhaard modus**: Normaliter als je de openhaard aan maakt, zal de thermostaat de verwarming af laten slaan omdat het warm genoeg is in de woonkamer. Omdat we geen zoneregeling hebben zorgt dit er echter voor dat de bovenverdieping ook niet meer warm wordt. Graag negeer ik de woonkamer temperatuur en laat ik 'm doordraaien op zijn stooklijn (gebaseerd op de buiten temperatuur).
- **Efficiëntere desinfectie run**: We zetten geregeld zelf de tank op 60 graden om lang te kunnen douchen en uitgebreid in bad te zitten. Dit is effectief een desinfectie run, dus die laat ik dan ook graag als zodanig meetellen, zodat hij niet onnodig een dag later zelf verzint om de tank op 60 graden te verwarmen.

## Vereisten

- Een op zichzelfstaand systeem, onafhankelijk van het functioneren van Home Assistant of het computer netwerk. Optimalisaties mogen best afhankelijk zijn van informatie van Home Assistant of het internet, maar de basisfunctionaliteit voor het verwarmen van het huis moet robust en onafhankelijk functioneren.
- Bij voorkeur zo min mogelijk zelfbouw hardware en zo veel mogelijk gebruik makend van bestaande hardware en open source software.
- Mogelijkheden om eigen logica te implementeren of bestaande logica zodanig aan te passen naar mijn wensen. Dit is ten slotte een hobby project :P.
- Alles van netstroom voorzien. Geen batterijen vervangen elk jaar.

## Implementatie

### Modbus RTU aansturing met een ESP32 microcontroller

Modbus RTU is een simpele 2 aderige interface (alleen de A+/B- aansluitingen zijn nodig. GND is optioneel) die direct tussen deze 2 apparaten werkt. Door een simpele fysieke verbinding te gebruiken en een microcontroller, in plaats van een afhankelijkheid te creëren op het computernetwerk of Home Assistant, kan dit zelfstandig functioneren.

![](/assets/images/daikin_altherma_3/uart-to-rs485.png){: width="300" } ![](/assets/images/daikin_altherma_3/homehub-connectors.png){: width="300"} 

De Daikin Home Hub (2e afbeelding) heeft naast stroom en een P1P2 verbinding (zie X6A op de afbeelding), ook een RS485 interface (zie X8A). Dit is voor Modbus RTU. Deze is makkelijk aan te sturen met een ESP32 microcontroller met een UART-naar-RS485 transceiver (1e afbeelding). 

In de afbeelding hieronder zie je een behuizing met daarin een ESP32 microcontroller, een RS485 transceiver (MAX485 IC) en een display. Jurjen had deze al eerder gebouwd voor een ander project, en heeft voor mij een zelfde combinatie gebouwd met een display en transparante behuizing, welke ik zonder enige verdere aanpassingen kan gebruiken. Neat! Dank Jurjen! De combinatie van ESP32 en RS485 transceiver is heel gangbaar, waardoor dit in de toekomst ook makkelijk te vervangen is mocht het defect raken. 

[![](/assets/images/daikin_altherma_3/esp32_modbus.jpg){: width="400" }](/assets/images/daikin_altherma_3/esp32_modbus.jpg)

De grijze kabel is de RS485 verbinding met de Daikin Home Hub, en de zwarte USB kabel dient alleen voor voeding. Deze microcontroller plaatsen we samen met de Daikin Home Hub in de meterkast.

{% mermaid %}
graph LR;
    MK[ESP32] -->|Modbus RTU| DHH[Daikin Home Hub]
    DHH -->|P1P2 bus| WP[Warmtepomp]
{% endmermaid %}

### De woonkamer temperatuur meten

![](/assets/images/daikin_altherma_3/airgradient.png){: width="400" }

Ik de woonkamer had ik al een AirGradient luchtkwaliteitsmeter staan, die ik ook al voorzien had van ESPHome en een display heeft die wat nuttige informatie kan tonen. Ik hergebruik graag deze in plaats van weer een extra apparaat in de woonkamer te hebben staan. Deze kan prima aan de muur hangen waar nu de thermostaat zit. Aangevuld met wat icoontjes voor warmtevraag en of de tapwater tank gevuld wordt.

In theorie kan ik deze 2 apparaten samenvoegen, maar aangezien ik graag zo min mogelijk aanpassingen of zelfbouw hardware wil gebruiken, is het handiger om deze aan elkaar te koppelen. Aangezien ze beiden een ESP32 gebruiken en deze beschikken over Bluetooth, is dit erg gemakkelijk draadloos te doen met Bluetooth Low Energy! De thermostaatdraden in de muur zijn dus alleen nodig voor voeding.

### Thermostaat logica

Nu is de vraag, in welke van de twee ESP32s draaien we de thermostaat logica? Traditioneel draait dit in het apparaat aan de muur in de woonkamer. Maar, ik heb een beter idee en kies er voor om dat in de meterkast te draaien. Dit maakt dat de AirGradient in de woonkamer zich alleen als een generieke bluetooth temperatuur sensor hoeft te gedragen en dus in de toekomst eventueel te vervangen is door iets anders, of meerdere sensoren bijv voor zoneregeling.

Ook maakt dit het systeem in zijn geheel robuster, omdat bij het wegvallen van de bluetooth verbinding met de AirGradient, de verwarming nog steeds beperkt zal kunnen functioneren, gebaseerd op alleen de buiten temperatuur die door de buitenunit wordt gemeten.

## Overzicht componenten

Inmiddels zijn het best wat componenten geworden, maar de basis is nog relatief simpel.

{% mermaid %}
graph TD;
    MK[ESP32 meterkast met thermostaat logica] -->|Modbus RTU| DHH[Daikin Home Hub]
    AG[AirGradient Woonkamer] -->|Bluetooth Low Energy| MK
    DHH -->|P1P2| WP[Warmtepomp]
{% endmermaid %}

Betrekken we ook de optionele communicatie en ESPAltherma bijvoorbeeld (als stippelijntjes), dan krijgen we het volgende schema.

{% mermaid %}
graph TD;
    AG[AirGradient Woonkamer] -->|Bluetooth Low Energy| MK
    MK[ESP32 meterkast] -->|Modbus RTU| DHH[Daikin Home Hub]
    HA[Home Assistant] -.->|ESPHome over Wifi| AG
    DHH -->|P1P2| WP
    DHH -.->|Ethernet| Router/Internet
    HA -.->|ESPHome over Wifi| MK
    WP[Warmtepomp] -.->|X10A| ESPAltherma
    ESPAltherma -.->|MQTT over Wifi| HA    
{% endmermaid %}

## ESPHome

Voor de firmware op de ESP32 heb ik ESPHome gebruikt, omdat dit al ondersteuning voor [modbus](https://esphome.io/components/modbus_controller.html) en thermostaat logica aan boord heeft en de verdere (optionele) communicatie met Home Assistant dan erg gemakkelijk is. 

Let wel op dat ESPHome de verbinding met Home Assistant of wifi verliest, hij by default periodiek zal herstarten. Het is handig dit langer in te stellen dan de standaard waarde. Zie ook [ESPHome documentatie: ESPHome intentionally reboots in specific situations](https://esphome.io/guides/faq.html#my-node-keeps-reconnecting-randomly) hierover.
{: .notice--warning}

## Woonkamer temperatuur via BLE

Helaas heeft ESPHome alleen ondersteuning voor het lezen van BLE sensors, en kan het out-of-the-box niet acteren als een BLE sensor. Gelukkig is er iemand zo gek om dit als extern component te implementeren. Zie [github.com/wifwucite/esphome-ble-controller](https://github.com/wifwucite/esphome-ble-controller) voor het component. Met wat configuratie heb ik nu een AirGradient die zich ook als een BLE sensor gedraagt.

```yaml
external_components:
  - source: github://wifwucite/esphome-ble-controller

esp32_ble_controller:
  security_mode: none # have fun...
  maintenance: false # disable writable commands
  services: # generate some random UUIDs for these
    - service: "e3320996-230d-4c34-b014-2ae1b8d796d6"
      characteristics:
        - characteristic: "f63b8964-d886-4e4e-96c4-5ec1370d8734"
          exposes: temp
        - characteristic: "bc2ce2d5-3305-4e29-b681-6b4f2870b7d0"
          exposes: humidity
```

Zodra je de AirGradient hiermee opstart, check dan even de logs voor het mac adres. Dit heb je verderop nodig. Let op, dit is een ander mac adres dan de wifi, en verschilt vaak alleen in de laatste letter.
```
...
[23:24:34][C][esp32_ble_controller:318]: Bluetooth Low Energy Controller:
[23:24:34][C][esp32_ble_controller:319]:   BLE device address: 84:fc:e6:02:5a:ce
...
```

Aan de andere ESP zijde is de volgende configuratie voldoende om deze als sensor beschikbaar te maken. 

```yaml
esp32_ble_tracker: # vereist onderdeel

ble_client:
  # Het BLE mac adres van de AirGradient
  - mac_address: AB:CD:EF:12:34:56 
    id: airgradient_woonkamer

sensor: 
  # Temperatuur. Doe hetzelfde voor de luchtvochtigheid.
  - id: airgradient_woonkamer_temperature_ble
    platform: ble_client
    type: characteristic
    ble_client_id: airgradient_woonkamer
    name: "AirGradient Woonkamer Temperature BLE"
    service_uuid: "8a8e4590-3b3f-4343-acea-d59fc70e04fd"
    characteristic_uuid: "ae879a07-2182-4ec1-926e-b4a214769421"
    icon: "mdi:thermometer"
    unit_of_measurement: "°C"
    notify: true
    accuracy_decimals: 2
    # Nothing to see here, 
    # just some magic to convert the bytes to a float
    lambda: |-
      return *((float*)(&x[0]));
```

De BLE verbinding is een actieve verbinding. Dit heeft als voordeel dat de ESP32 weet wanneer deze weg valt. Dit is fijn voor monitoring, maar dat betekent ook dat we kunnen bepalen hoe onze thermostaat logica hiermee om gaat. Voor nu heb ik ESPHome geconfigureerd dat hij de laatst bekende waarde gebruikt. Dit is prima voor kortstondig uitvallen van het signaal. Dit kan nog uitgebreid worden met bijvoorbeeld terugvallen op de stooklijn wanneer hij langer tijd wegvalt.

```yaml
  - platform: template
    id: airgradient_woonkamer_temperature
    name: "AirGradient Woonkamer Temperature"
    # translate unavailable to 0
    lambda: |-
      if (id(airgradient_woonkamer_temperature_ble).state > 5 && id(airgradient_woonkamer_temperature_ble).state < 50) {
        return id(airgradient_woonkamer_temperature_ble).state;
      } else {
        return 0;
      }
    update_interval: 5s
    accuracy_decimals: 2
    icon: "mdi:thermometer"
    unit_of_measurement: "°C"
    filters:
      # ignore unavailable (0) value
      - clamp:
          min_value: 5
          max_value: 50
          ignore_out_of_range: true
```

## Modbus verbinding

Op de website van Daikin is (onderaan de pagina) de "[Installatie handleiding voor installateur](https://www.daikin.nl/nl_nl/installateurs/products/product.html/EKRHH.html)" te vinden. Hierin staan een aantal parameters voor de Modbus RTU interface van de Daikin Home Hub.

![](/assets/images/daikin_altherma_3/rs485-parameters.png){: width="600" }

Vervolgens heb ik gebaseerd op de ESPHome documentatie voor de [Modbus Controller](https://esphome.io/components/modbus_controller.html) de volgende YAML configuratie gebruikt. Let op dat de GPIO pins, baud rate en het nodig hebben van een flow control pin specifiek zijn voor de MAX485 IC. Check hoe jouw specifieke IC en/of transceiver aangesloten is en stel deze correct in. 

```yaml
uart:
  id: mod_bus
  tx_pin: GPIO17
  rx_pin: GPIO16
  baud_rate: 9600

modbus:
  id: modbus1
  uart_id: mod_bus
  flow_control_pin: GPIO18

modbus_controller:
  - id: daikin_ekrhh
    # Dit adres stel je in bij het aansluiten van 
    # de Home Hub op de warmtepomp.
    address: 0x1 
    modbus_id: modbus1
    setup_priority: -10
    update_interval: 20s
```

### Registers lezen en schrijven

Nu we verbinding hebben met de Daikin Home Hub, kunnen we registers lezen en schrijven. Modbus kent een aantal registers, maar de Daikin Home Hub gebruikt er maar 2:
- **Holding Registers**: Deze kunnen gelezen en geschreven worden.
- **Input Registers**: Deze kunnen alleen gelezen worden.

De handleiding defineert ook enkele formaten voor waardes in deze registers.
![](/assets/images/daikin_altherma_3/modbus-register-formats.png){: width="600" }

Vervolgens publiceert de handleiding een lijst van waardes die we kunnen lezen en schrijven.

![](/assets/images/daikin_altherma_3/holding_registers.png){: width="600" }

Welke in ESPHome als volgt gebruikt kunnen worden:

```yaml
number:
  - platform: modbus_controller
    modbus_controller_id: daikin_ekrhh
    name: "Leaving water Main Heating setpoint"
    register_type: holding
    address: 0
    unit_of_measurement: "°C"
    value_type: S_WORD # Dit is een 16-bit integer
    min_value: 25 # deze zijn je min en max stooklijn waarden
    max_value: 35
    lambda: |-
      if (x > 100 || x < 0) { return NAN;}
      return x;

  - platform: modbus_controller
    modbus_controller_id: daikin_ekrhh
    name: "Leaving water Main Cooling setpoint"
    register_type: holding
    address: 1
    unit_of_measurement: "°C"
    value_type: S_WORD
    min_value: 17
    max_value: 20
    lambda: |-
      if (x > 100 || x < 0) { return NAN;}
      return x;

select:
  - platform: modbus_controller
    id: operation_mode_select
    name: "Operation mode"
    address: 2
    value_type: S_WORD
    optionsmap:
      "Auto": 0
      "Heating": 1
      "Cooling": 2
```

Eenmaal de ESPHome firmware gebouwd en aan Home Assistant toegevoegd, wordt dit als volgt weergegeven in Home Assistant:

![](/assets/images/daikin_altherma_3/ha-ui.png){: width="600" }

### Nuttige registers

Ok, absolute waardes voor aanvoer temperatuur doorgeven is leuk, maar eigenlijk wil ik de warmtepomp de dingen laten doen waar hij goed in is, en ik voeg er wat aan toe. Dus registers voor manipulatie van de stoolijk zijn interessanter. Hieronder een overzicht van de registers die ik gebruik en waarvoor. Hou er rekening mee dat ik de thermostaat van Daikin dus afkoppel en de unit zelf alleen beschikking heeft over de buitentemperatuur, gemeten door de buitenunit.

- **Operation mode: Auto, Heating, Cooling**: Auto zal automatisch switchen tussen koelen en verwarmen. Ik zal dit explicitet op koelen of verwarmen zetten, omdat the climate component van ESPHome hiermee beter werkt.
- **Space heating/cooling: ON/OFF**: Dit schakelt de ruimteverwarming aan of uit. Zie ook "In bedrijf" in het menu van de warmtepomp. Dit gebruik ik om de warmtepomp te vertellen af te schakelen bij een te hoge woonkamer temperatuur.
- **DHW setpoint**: Absolute gewenste tank temperatuur. Werkt alleen als de warmtepomp in "Fixed" setpoint. Aangezien ik zelf logica wil maken voor de desinfectie run, en onderscheid wil maken in 2 krachtig-modussen (1 tot de max van de buitenuit: 55 graden, en de ander tot het maximum van de binnenunit: 60 graden), en een eventuele stooklijk niet moeilijk is zelf te bouwen, zal ik deze als absolute waarde zelf instellen.
- **DHW reheat ON/OFF**: Uitschakeling van de tank verwarming. Zie ook "In bedrijf" in het menu van de warmtepomp. Handig voor op vakantie.
- **DHW booster mode ON/OFF**: Dit activeert de booster mode van de warmtepomp. Dit is een extra verwarming die de warmtepomp aan kan zetten om de tank sneller op temperatuur te krijgen. De termperatuur hiervoor heb ik op de warmtepomp ingesteld op 60 graden. Dit wordt de meest krachtige van de 2 krachtig-modussen.
- **Weather dependent mode - Main LWT Heating setpoint offset**: Als de warmtepomp op stooklijn staat ingesteld voor ruimteverwarming (waarom zou je 'm op iets anders stellen?), dan kan je deze offset gebruiken om de stooklijn te manipuleren. Stel deze in op -1 om de stooklijn te verlagen met 1 graad. Dit gebruik ik om modulatie te implementeren. Er is ook een cooling, maar het stooklijk-bereik in temperatuur voor koelen is zo beperkt, en in de praktijk is het in de woonkamer altijd 2 graden ofzo hoger dan het koelen-setpoint, dat modulatie in de parktijk niets doet.
- **Smart Grid operation mode**, **Power limit during Recommended on / buffering** en **General power limit**: Deze registers zijn voor het instellen van de maximale vermogen van de warmtepomp. Dit is handig voor het eigenverbruik van de zonnepanelen te optimaliseren en energie te bufferen in de vloerverwarming en tank. 

## Thermostaat logica

Ok, nu voor de thermostaat logica. ESPHome heeft hiervoor een [component](https://esphome.io/components/climate/thermostat.html) die je naar hartelust kunt configureren.

```yaml
climate:
  - platform: thermostat
    id: woonkamer_thermostaat
    on_boot_restore_from: memory
    name: Woonkamer Thermostaat
    icon: mdi:heat-pump

    visual:
      min_temperature: 18
      max_temperature: 25
      temperature_step: 0.1

    # Sensors
    sensor: airgradient_woonkamer_temperature
    humidity_sensor: airgradient_woonkamer_humidity

    # Presets
    default_preset: Normal
    preset:
      - name: Normal
        default_target_temperature_low: 20.2
        default_target_temperature_high: 23.5
        mode: heat_cool
      - name: Vacation
        default_target_temperature_low: 19.0
        default_target_temperature_high: 23.5
        mode: heat

    # Some safeguards
    min_cooling_off_time: 60s
    min_cooling_run_time: 60s
    min_heating_off_time: 60s
    min_heating_run_time: 60s
    min_idle_time: 60s
    startup_delay: true
    set_point_minimum_differential: 1

    # Deadbands
    cool_deadband: 0.5
    cool_overrun: 0.0
    heat_overrun: 0.5
    heat_deadband: 0.2

    # Actions
    cool_action:
      ...
    heat_action:
      ...
    idle_action:
      ...
```

In de `*_action:` kun je de **Operation mode: Auto, Heating, Cooling** en **Space heating/cooling: ON/OFF** registers manipuleren. Voordat je dat echter doet, stel de warmtepomp in op het aansturen van de aanvoer temperatuur, inplaats van de woonkamer thermostaat, en ontkoppel de bedrading van de Madoka-thermostaat.

Vervolgens ziet het er in Home Assistant prachtig uit:

![](/assets/images/daikin_altherma_3/ha_thermostat.png){: width="400" .align-center }

## Tweaking en features

Dit component heeft wel een maar... Als de woonkamer temperatuur zich binnen de deadband/overrun bevindt, en de microcontroller reboot, zal de thermostaat springen naar "idle", ookal stond deze eerder op "heating". Het gevolg hiervan is dat de warmtepomp uitgeschakeld wordt bij een microcontroller reboot, totdat hij weer de onderkant van de deadband bereikt. Aangezien we de huidige status van de warmtepomp weten door een modbus register te lezen, kunnen we hier omheen werken. De workaround hiervoor is echter oerlelijk... namelijk, het tijdelijk verhogen van de thermostaat setpoint, zodat deze activeert, om die vervolgens weer terug te zetten. :facepalm:

Naast het heractiveren van de thermostaat na een reboot, en het toevoegen van de stooklijn modulatie, zijn er ook andere tweaks. Zoals niet wachten totdat je de deadband bereikt, maar al eerder de warmtepomp aanzetten als je weet dat het buiten koud is. Hierdoor voorkom je dat de lange opstart en opwarmtijd van de warmtepomp er voor zorgt dat de woonkamer temperatuur nog even verder doordaalt onder het setpoint, en je 'm dus netjes kunt laten "landen" op het setpoint. Of het optimaliseren van de tank desinfectie: als ik 'm zelf op 60 heb gezet, ga dan niet de dag erna dit vrolijk nog een keer doen.

Daarnaast zijn er features die ik wil toevoegen, zoals een automatische openhaardmodus, en het meenemen van zoninstraling in de woonkamer, en hoeveelheid mensen in de woonkamer in de bepaling van de effectieve modulatie. Dit alles om de woonkamer temperatuur verder te stabiliseren.

Meer hierover in een volgende post.
