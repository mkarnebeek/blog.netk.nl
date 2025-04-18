---
title: "ZHA netwerk stabiliteit verbeteren"
tags: ZHA zigbee
excerpt: Stappen die ik doorlopen heb om mijn ZHA netwerk stabiliteit te verbeteren.
---

# Situatie

Het ZHA netwerk had al een tijdje moeite met battery-powered nodes online te houden. ![Xiaomi presence sensor](/assets/images/zha/xiaomi-motion.webp){: .align-right width="100"} Vooral met de verschillende Xiaomi sensors. Deze staan er wel om bekend moeite te hebben met bepaalde routers. Ze hadden ook wel eens issues op het deCONZ netwerk, dus in eerste instantie leek het vooral aan die motion sensors te liggen.

Ook zag ik al een tijdje de volgende log regel voorbij komen, maar deze verdween na verloop van tijd.

```
Zigbee channel 24 utilization is 99.52%!
```

Ik kwam er tot dusver telkens mee weg door een sensor opnieuw te pairen. Het kwam niet vaak genoeg voor om er een heel netwerk voor overhoop te gooien (migratie naar Zigbee2MQTT?) en ik heb monitoring staan op het onbeschikbaar gaan van devices, dus ik was het (meestal) Marjolijn of de kids voor.

Intussen was ik al wel 2 jaar bezig om van deCONZ naar ZHA te migreren en eigenlijk wou ik dat wel een keer afronden. Maar om dat te kunnen moet eerst het ZHA netwerk stabieler zijn.

Over het stabiel krijgen van een zigbee netwerk is meer dan genoeg geschreven op het internet. Een forum post die ik zelf heel nuttig vond was [deze van Hedda](https://community.home-assistant.io/t/zigbee-network-optimization-a-how-to-guide-for-avoiding-radio-frequency-interference-adding-zigbee-router-devices-repeaters-extenders-to-get-a-stable-zigbee-network-mesh-with-best-possible-range-and-coverage-by-fully-utilizing-zigbee-mesh-networking/515752). Daardoorheen lezende dacht ik alles al wel een keer geprobeerd te hebben. USB2 verleng-kabel iemand? Of het [channel overlap diagram tussen Zigbee en Wifi](https://www.metageek.com/training/resources/zigbee-wifi-coexistence/) van Metageek bijv? Wel is met de jaren [https://www.home-assistant.io/integrations/zha](https://www.home-assistant.io/integrations/zha) flink uitgebreid en bevat veel nuttige informatie. 

![Zigbee channel overlap](/assets/images/zha/zigbee-channels.png){: .align-center width="80%"}

De volgende stap zou een migratie naar Zigbee2MQTT overwegen zijn, en een rabbit-hole in de wereld van zigbee firmwares en chipsets. Daar had ik nog niet zo veel zin in. Sterker nog. De afgelopen jaren wil ik juist complexiteit reduceren. Denk bijvoorbeeld aan influxdb en grafana uitfaseren omdat het energie dashboard en statistieken opslag van Home Assistant zo veel verbeterd zijn. Dus als ik de keuze heb tussen deCONZ, ZHA en Zigbee2MQTT, dan heeft ZHA wel de voorkeur. 

# Coordinator verplaatsen

In ZHA kun je "Diagnosiek" downloaden. ![Diagnosiek downloaden](/assets/images/zha/diag.png){: .align-right width="350"} In de json die je dan krijgt, vind je een energy scan per zigbee kanaal. Dit werkt een stuk beter dan je eigen wifi en zigbee kanalen instellen zodat ze niet overlappen met behulp van bovenstaand overzicht. Immers, je hebt ook buren en andere stoorzenders. Zoals wel bleek uit mijn energy scan. Uiteraard al eens geprobeerd de USB stick hoger in de meterkast te hangen, zo ver mogelijk weg van andere apparatuur. Maar de meterkast bleef een probleem, dus het werd tijd om e.e.a. te verhuizen van de meterkast naar zolder.

```
    "energy_scan": {
      ...
      "20": 99.244260188723507,
      "21": 92.0598007161209,
      "22": 94.48255331375627,
      "23": 92.0598007161209,
      "24": 78.25348754651363,
      "25": 95.26028270288712,
      ...
    },
```

De enige reden waarom mijn servertje in de meterkast moet staan, is omdat hij vast zit aan de P1 poort van de slimme meter. Daar zijn tegenwoordige ook ethernet oplossingen voor.

Bijvoorbeeld [deze van Marcel Zuidwijk](https://www.zuidwijk.com/product/p1-reader-ethernet/). ![](/assets/images/zha/p1lezer.png){: .align-right width="40%" } Die is 5 euro goedkoper dan de [ESPHome-based versie](https://www.zuidwijk.com/product/slimmelezer-wt32-eth01/) en achteraf had ik misschien ook voor die 2e moeten gaan. Die eerste bevat namelijk wat chinese software, en ik heb zelf wel een voorkeur voor open firmware. Hoe dan ook, hang 'm op een eigen VLAN die ik ook gebruik voor de chinese robot stofzuigers bijvoorbeeld, en het werkt ook goed genoeg :P.

Inmiddels draait de server op zolder, en ziet de energy scan er een stuk beter uit. Nog steeds functueren de waardes enorm, en is het mij nog niet direct duidelijk welk kanaal nu handig is om te selecteren.

Ik had nog niet eerder ZHA over-the-air firmware upgrades gebruikt voor mijn zigbee apparaten, aangezien in de UI met een grote waarschuwing aangegeven wordt dat dit een stabiel netwerk vereist. Op dit punt dit maar eens geprobeerd, en het werkte voor 6-7 devices (battery powered) erg goed! 1 device had een poging of 2 nodig, maar verder zonder issues. Het lijkt er op dat we voortgang boeken!

# Channel energy meten over langere periode

Om goed te kunnen bepalen welk kanaal nummer handig is om te gebruiken, moeten we eigenlijk over langere tijd deze energy waardes weten.

Met de volgende yaml configuratie maak je een rest-sensor aan in Home Assistant, die zijn eigen API aan roept om deze energy levels beschikbaar te maken in een sensor.

Zoek even je `config_entry` op door in je webbrowser naar de URL te kijken wanneer je je ZHA integration bezoekt. En je `Bearer token` kun je aanmaken in je user in Home Assistant onder "Beveiliging" en dan "Long-lived access tokens".

In mijn omgeving leek het alsof Home Assistant, ZHA en/of the coordinator kortstonding blokkeert wanneer hij de diagnostiek verzamelt. De volgende code doet dit elke minuut. Terwijl dit draait kan het dus wat vertraging op het netwerk opleveren elke keer dat hij de diagnostiek ophaalt.
{: .notice--warning}

```
{% raw %}
  sensor:
    - platform: rest
      unique_id: zha_energy
      name: zha_energy
      unit_of_measurement: "%"
      timeout: 30
      resource_template: http://ha.home.netk.nl:8123/api/diagnostics/config_entry/b17ea026bbb888d77f3e1ebbb9189cf9
      headers:
        Authorization: >
          Bearer eyJh...[snip]...7dPg
      value_template: >-
        {% set channel = value_json.data.application_state.network_info.channel %}
        {% set energy_scan = value_json.data.energy_scan %}
        {{ energy_scan[channel|string] }}
      json_attributes_path: "$.data.energy_scan"
      json_attributes: ["11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26"]
{% endraw %}
```

Vervolgens kun je deze bijvoorbeeld weergeven in Grafana. Hiermee is goed te bepalen welk kanaal nummer goed werkt.

![](/assets/images/zha/zha_energy_grafana.png){: .align-center width="80%" }


# Router toevoegen

Ooh, maar ik heb genoeg routers... Toch? Elke netstroom-powered node werkt als versterking voor je Mesh. En toch is de ene router de andere niet. In het netwerkoverzicht in ZHA waren veel rode lijnen te zien. Vooral bij de [IKEA Trådfri ledstrip drivers](https://www.ikea.com/nl/nl/p/tradfri-driver-voor-draadloze-besturing-smart-grijs-60342656/) was dit het geval. 

![](/assets/images/zha/smlight_snlzbbnlziets-06m.png){: .align-center width="50%" }

Inmiddels is er een erg populair apparaat op de markt van SMLight, de [SLZB-06M](https://smlight.tech/product/slzb-06m/). Mijn voornaamste reden dit te gebruiken is de radio en antenne combinatie. Als [deze youtuber](https://www.youtube.com/watch?v=QckXMMxDF0k) er 80 meter mee kan overbruggen, moet het bij mij thuis toch ook goed werken?


Daarnaast ben ik persoonlijk enorm fan van dit apparaat. Het kan gevoed worden door USB-C of POE, gefabriceerd in Oekraïne, kost maar 35 euro op Aliexpress en bevat zeer goede firmware (Home Assistant support out-of-the-box).

![](/assets/images/zha/snlzbbnldinges_ui.png){: .align-center width="90%" }

Aan de hardware kant gebruikt het een ESP32, heeft eventueel support voor ESPHome als je dat wil, en de zigbee chip is dezelfde die in de Sky Connect / ZBT-1 gebruikt wordt (Silicon Labs ERF32MG21). Je kun je eigen firmware naar keuze flashen op de zigbee chip, of kiezen uit de laatste router of coordinator firmware van Silicon Labs. Zelfs Matter-over-thread support is er. Ook is het gemakkelijk migreren van de ZBT-1 naar de SLZB-06M. Het komt ook nog in een aantal andere variaties (zoals de SLZB-06, zonder de M dus) die een chipset (Texas Instruments CC2652P) bevat die goed ondersteund wordt in Zigbee2MQTT, maar sinds begin 2025 is de support voor de Silicon Labs chipset in Zigbee2MQTT van experimenteel naar officieel supported gepromoveerd.


# Source routing inschakelen

ZHA gebruikt iets wat heet Table Routing. Dit leunt op router devices in je netwerk om een tabel bij te houden van nodes die zij kunnen zien. Aangezien het algemeen bekend is dat niet elke fabrikant dit op dezelfde manier implementeert en sommigen zelfs gewoon niet goed werken, is het eigenlijk vragen om problemen. Oude Hue lampen combineren met Xiaomi battery-powered sensors? Gegarandeerd issues.

Het alternatief (default bij Zigbee2MQTT) is Source Routing. Hierbij bepaalt de coordinator de route door het netwerk voor een bericht. Ook ontstaat er minder broascast verkeer.

Cem Basoglu schreef een tijdje geleden een [dijk van een artikel hierover](https://meshstack.de/post/home-assistant/zigbee-table-routing-vs-source-routing-zha/), en het inschakelen hiervan is super simpel. Ook kan er weinig mis gaan: Als het netwerk na een paar uur niet stabiliseert en re-pairen van moeilijke sensoren niet lukt, schakel je het weer uit.

```
  zha:
    zigpy_config:
      source_routing: true
```

Na het inschakelen kan het een aantal uur duren voordat routers hun tables niet meer updaten en het netwerk echt pas leunt op Source Routing. Verwacht dus nodes die een tijdje onbereikbaar worden, of soms re-pairen vereisen om weer goed op het netwerk te werken.

# Zigbee traffic sniffing

Toch bleven er soms sensors van het netwerk af vallen. Soms was het gewoon een lege batterij :facepalm:, maar vaak ook problematische nodes die er maar af bleven vallen.

Diezelfde Cem schreef nog een [dijk van een artikel over hoe je op het netwerk verkeer kunt sniffen](https://meshstack.de/post/home-assistant/zigbee-sniffer-guide/), en zo dus mee kunt kijken waar het precies mis gaat. Door nog een SMLight SLZB-06M aan te schaffen, [ember-zli](https://github.com/Nerivec/ember-zli) te installeren (zie Cem's artikel en de Readme van het project), wat encryptie sleutels van mijn netwerk in te voeren, had ik al snel Wireshark aan het meekijken op mijn netwerk.

Zo trof ik een Xiaomi sensor die door Home Assistant inmiddels als onbeschikbaar gemarkeerd was. In plaats van deze de zoals gebruikelijk re-pairen, maar eens mee gekeken met Wireshark wat er aan de hand was. (Het adres van de node is te vinden in Home Assistant bij het apparaat als NWK adres). Eerst maar eens kijken of ik iets op het netwerk zag door de sensor wakker te maken. Het ging om een trillings-sensor, maar er tegen aantikken deed niets. Kort op het knopje drukken wel (dus niet resetten).


![](/assets/images/zha/ikmoetjounie.png){: .align-center width="90%" }

Ah! Wireshark licht op en ik zie verkeer van of naar die sensor gaan. Oke, eerste pakket is een Rejoin request. Cool. Echter, er is een andere node op het netwerk die duidelijk geen vriendjes meer is met die sensor... Leave??? Nou, doe 's lief...

Die andere node blijkt een Innr E14 lampje te zijn... aan de andere kant van het huis?? Uhm.. die heeft wel eens vaker kuren gehad, en een keer herstarten (fysieke schakelaar uit en aan zetten) heeft meer dan eens geholpen om andere sensors terug te krijgen. Nou, zodoende dus die eens uit en weer aan gezet. Nog eens op het knopje van de Xiaomi trillings-sensor gedrukt (wederom geen reset dus), en warempel!

![](/assets/images/zha/ohja-tochweltoch.png){: .align-center width="90%" }

Dit keer reageert mijn eerste SLZB-06M als router op het Rejoin request, en weet de sensor opnieuw het netwerk te joinen zonder een reset / re-pair! Dit help wel met het vinden van problematische routers!

# Huidige situatie en volgende stappen.

Ik heb nu 2 SLZB-06M's in huis. Één als router, en de ander als sniffer. Op termijn wil ik de Sky Connect / ZBT-1  die nu als coordinator functioneert migreren naar een van dezen, omdat ze zoveel makkelijker te plaatsen zijn in huis met POE. Ook ga ik problematische routers vervangen door betere routers (die Inner lamp), omdat ik op dit moment denk dat dit de hoofd oorzaak is van sensors die zo af en toen verdwijnen. Daarnaast zijn er soms sensoren die door Home Assistant als onbeschikbaar gemarkeerd worden, maar het eigenlijk nog doen: Dit zijn vocht en motion-sensors die bij detectie prima Home Assistant bereiken en weer online worden.

Op dit moment heb ik echter weer iets leuks geleerd, werkt het stabiel genoeg en zijn er duidelijke diagnose stappen te nemen bij problemen. Voorlopig dus even weer een probleem opgelost.