---
title: "Daikin Altherma 3 lokaal aansturen"
tags: Daikin Warmtepomp Modbus
excerpt: Ons huis wordt sinds februari 2023 verwarmd door een Daikin Altherma 3 warmtepomp. Dit is mijn zoektocht naar een lokale aansturing ervan.
---

![](/assets/images/daikin_altherma_3/units.png){: width="300" align="right"}

Ons huis wordt sinds februari 2023 verwarmd door een Daikin Altherma 3 warmtepomp en zijn we van het gas af. Dit is een split-unit dat zowel de verwarming van het huis op zich neemt, als het warm tapwater. Het bestaat uit een buitendeel, wat een normale airco installatie ook heeft, en een binnendeel waarin o.a. leidingwerk, een warmtewisselaar en de warm tapwater tank zit. 

Nadat deze geinstalleerd was, heb ik hem eerst maar eens uitgelezen met ESPAltherma. Hiermee kon ik 'm optimaliseren. Om 'm te kunnen bedienen via Home Assistant gebruikte ik de Onecta [integratie van Johnny Willemsen](https://github.com/jwillemsen/daikin_onecta), maar dit werkt alleen via de cloud.

In de loop der tijd ondekte ik gedrag aan de warmtepomp welke ik graag wilde verbeteren. Daarnaast was er volgends de documentatie een mogelijkheid om energie te bufferen in de tapwater tank of de vloerverwarming, welke ik interessant vond.

Zo startte mijn zoektocht naar een lokale aansturing van de warmtepomp.

**Doelen**

- De unit volledig lokaal aansturen en integreren in mijn domotica. Denk aan automatisch temperaturen aanpassen op vakantie, of de tank extra verwarmen. Ook zit dan alles in één user interface, in plaats van voor elk "smart" apparaat een eigen app te hebben.
- Het mogelijk te maken om zelf thermostaat-logica te implementeren, om zo een aantal tekortkomingen van de unit op te lossen. Zie [een eigen thermostaat bouwen](/een-eigen-thermostaat-bouwen).
- Het mogelijk te maken om energie te bufferen in de tapwater tank of de vloerverwarming, om zo mijn eigen verbruik van de zonnepanelen beter te benutten en het net te ontlasten.

**Eisen**

Lokale communicatie met open protocollen waar mogelijk. Het moet een door Daikin officieel ondersteunde oplossing zijn. Geen reverse-engineering, of (niet-ondersteunde) aanpassingen aan de warmtepomp, aangezien dit met 2 kleine kinderen een vrij kritisch systeem van ons huis is :P.

## Interfaces

### De Cloud van Daikin: De Draadloze Gateway

Dit is sd-kaart achtige module die in de binnenunit geplaatst wordt. 
![](/assets/images/daikin_altherma_3/wifi-sd-card.png){: width="250" .align-right } Deze verbind via wifi met de cloud van Daikin. Dit is de moderne variant van 2 andere oplossingen welke allen uiteindelijk verbinding maken met de cloud van Daikin.

Naast dat ik communicatie via de cloud voor mijn domotica gewoon niet wil, is ook de ondersteuning van Daikin hiervoor erg beperkt. De app kan paar per halve graad de temperatuur instellen. Het schema is nog minder accuraat, waar je maar per 1 graad kan instellen.

Ook merk je dat ze niet dol zijn om externe systemen via deze route te ondersteunen. In het begin was er een Home Assistant integratie die met dezelfde API verbinding maakte, maar dit werd al snel door Daikin vervangen door de ONECTA Cloud API welke bedoeld was voor externe integraties zoals Home Assistant. Echter deze mocht je maar een beperkt aantal keren per dag aanroepen, en stelde deze mij niet in staat om de unit naar wens te besturen.

Zolang ik dus geen alternatief had, was dit de manier om te integreren met mijn domotica. Meh.

### De Smart-grid contacten

![](/assets/images/daikin_altherma_3/smart-grid.png){: width="400" }

O.a. ESPAltherma maakt hier gebruik van (zie verder), of je kunt zelf wat klussen met ESPHome bijvoorbeeld. De documentatie hiervan is goed, echter de mogelijkheden zijn erg beperkt. Deze Smart-grid interface is uit te breiden met 2 IO-boards van Daikin, welke je in staat stelt om uitgebreider bijvoorbeeld vermogenslimiten in te stellen, echter zijn deze erg prijzig voor de geleverde mogelijkheden, en kunnen deze nog steeds niet wat ik nodig heb, zoals bijvoorbeeld bepalen van de tank temperatuur.

### Het X10A serial poort

Het X10A poort is een intern poort op de binnenunit. Eigenlijk gebruik ik het poort liever niet, omdat je in staat bent interne ongedocumenteerde commando's naar de warmtepomp te sturen. Dit poort wordt ook gebruikt door Daikin engineers om bijvoorbeeld de firmware van de binnenunit te updaten (niet te verwarren met de user interface software op de binnenunit). Het is een actief protocol waarbij je dus een query voor informatie stuurt en een antwoord krijgt van de binnenunit.

Praktisch het enige open source project dat hiervan gebruik maakt is [ESPAltherma](https://github.com/raomin/ESPAltherma). Aangezien dit aleen queries stuurt voor het opvragen van data, en geen instelingen aanpast of opdachten geeft, lijkt het enigzins veilig. Ook wordt dit al door veel mensen gebruikt. 

![](/assets/images/daikin_altherma_3/espaltherma.png)

Het levert een schat aan informatie op. Met die informatie kun je perfect je warmtepomp optimaliseren.

![](/assets/images/daikin_altherma_3/grafana.png)

Het wijzigen van instellingen gebreurt echter altijd handmatig op de unit zelf, omdat het besturen van de warmtepomp is beperkt tot het met een relais aansturen van de smart-grid contacten van de binnenunit. Wijzigen van woonkamer thermostaat setpoint is er bijvoorbeeld niet bij.

### De P1P2 bus via Open Source

De P1P2 bus is een eigen bus van Daikin die zij al een aantal generaties van hun apparaten gebruiken om te communiceren tussen verschillende apparaten. Bij de warmtepompten wordt dit gebruikt tussen de thermostaat en de binnenunit (nope, geen OpenTherm dus). Dit is een 2-draads bus, welke je vrij kunt doorlussen tussen de verschillende apparaten. 

![](/assets/images/daikin_altherma_3/thermostat.png){: width="200" .align-right } In mijn geval was er een Madoka-thermostaat als enige apparaat hierop aangesloten, deze trouwens ookwel de "Interface voor menselijk comfort" noemt :P.

Er bestaat een open source project dat dit protocol ge-reverse-engineered heeft. Voormalig P1P2Serial en nu [P1P2MQTT](https://github.com/Arnold-n/P1P2MQTT). Gezien echter dat er geen officiele publieke documentatie van Daikin is voor P1P2, durfte ik hiermee niet de warmtepomp aan te sturen. Als ik een meer door Daikin ondersteunde manier kan vinden, heeft dat wel mijn voorkeur.

### De P1P2 bus en derde partijen

Daikin werkt wel samen met derde partijen om producten te ontwikkelen die gebruik maken van de P1P2 bus. Er is dus wel documentatie van deze bus welke door derde partijen gebruikt wordt om producten te ontwikkelen. Zodoende zijn er bijvoorbeeld best wat producten te vinden voor KNX die via P1P2 Daikin producten kunnen aansturen. Tot dusver heb ik mij daar om 2 redenen niet echt in verdiept: KNX is geen open protocol. Je betaalt licentiekosten voor software om dit the programmeren, en de meeste producten hebben beperkt ondersteuning voor Daikin Altherma 3.

### De P1P2 bus en Modbus producten van Daikin

Daikin heeft een aantal Modbus naar P1P2 producten op de markt. De volgende 3 ondersteunen de Altherma 3: DCOM-LT/MB, DCOM-LT/IO en de Daikin Home Hub (EKRHH). De eerste ondersteund alleen modbus, en de tweede zowel modbus als analoge ingangen.

![](/assets/images/daikin_altherma_3/dcom-lt-mb.png){: width="250" } ![](/assets/images/daikin_altherma_3/dcom-lt-io.png){: width="250" }

De DCOM-LT/IO beschikt over de mogelijkheden die ik zoek. De aansturing zou nog wat onhandig verlopen, omdat sommige features alleen als analoge ingangen beschikbaar zijn. Dit vereiste dus nog steeds best wel wel wat aansluitingen tussen een ESP32 en deze module, maar ik kom in de buurt van wat ik zoek.

Totdat Daikin de Daikin Home Hub (EKRHH) introducteerde!

### De P1P2 bus en de Daikin Home Hub

Dit is een vrij nieuw product van Daikin en is gefocussed op het eigen verbruik/opbrengst te optimaliseren. Hij wordt gemonteerd in de meterkast en is aangesloten op de P1P2 bus van de warmtepomp. Via een USB poort is een P1 kabel naar een slimme meter aan te sluiten, en dat is alles wat je nodig hebt om buffering in je vloerverwarming of tapwater tank te gebruiken. Woaw. Voor wat ik van Daikin gewend ben tot dusver aan IO boards bijv, is dit een futuristisch product!

![](/assets/images/daikin_altherma_3/ekrhh.png){: width="300" } ![](/assets/images/daikin_altherma_3/ekrhh-connect.png){: width="300" }

Ook ondersteunde het een Modbus modus, waarin alle slimmigheid uitgeschakeld wordt, en er gekozen kan worden tussen Modbus RTU (serieel) of Modbus TCP toegankelijk over het ethernetpoort. Wat ik van de documentatie mag geloven, stelt dit alle mogelijkheden beschikbaar voor de Altherma 3 die ik zoek.

## Verder bouwen

Na het bekijken van opties voor lokale aansturing, lijkt de Daikin Home Hub de beste keuze. Aangevuld met ESPAltherma voor het uitlezen van data dat de Home Hub niet kan leveren.

Het idee is om een ESP32 met ESPHome te gebruiken om over Modbus RTU met de Daikin Home Hub te communiceren. De Daikin Home Hub zal dan enkel als modbus interface dienen om de Altherma 3 aan te sturen. Zie [Een eigen thermostaat bouwen](/een-eigen-thermostaat-bouwen) hoe dit verder ging.

## Aanschaffen Daikin Home Hub

Het aanschaffen van de Daikin Home Hub was nog wel een dingetje, want dik 600 euro neertellen voor een router-formaat kastje dat niets meer doet dan bridgen tussen de P1P2 bus en Modbus, vond ik nogal prijzig. Na wat prijzen op vooral duitse websites een tijdje in de gaten houden, vond ik er een voor net boven de 300 euro. Toen 'm toch maar aangeschaft.

## Software update?

Na het aanschaffen en installeren van de Daikin Home Hub bleek echter dat de binnenunit nog een software update nodig had om te communiceren met de Daikin Home Hub. Het ging om de firmware op de binnenunit, de zogeheten "Micon ID binnen". Dit ging niet om de MMU, ofwel de user interface die je op de binnenunit ziet, maar om de firmware op het mainboard van de binnenunit. 

![](/assets/images/daikin_altherma_3/required-micon-id.png){: width="400" }

*Uit de uitgebreide installateurs handleiding van Daikin, de vereiste Micon ID versie voor de binnenunit om te kunnen communiceren met de Daikin Home Hub. Ik had versie 0222, wat dus niet voldoet.*

Dit was een lang proces bij Daikin en verliep allerminst vlekkeloos. Na maanden touwtrekken kwam er eindelijk een engineer van Daikin die mij de firmware update kon uitvoeren, waarna de Daikin Home Hub werkte zoals verwacht. Daikin deed dit voor mij uiteindelijk gratis, voornamelijk door de onduidelijkheid aan hun kant. Verwacht hier normaliter ook ruim 300 euro voor te betalen. 

## Eindelijk! En toen?

Ik heb nu eindelijk op een officieel ondersteunde manier, volledig lokaal, via een open protocol controle over mijn warmtepomp en kan nu mijn eigen thermostaat bouwen! Zie [Een eigen thermostaat bouwen](/een-eigen-thermostaat-bouwen) waar ik verder in ga op hoe ik met ESPHome een eigen thermostaat bouwde en uiteindelijk die van Daikin verving en veel betere resultaten kreeg.
