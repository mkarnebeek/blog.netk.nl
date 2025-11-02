---
title: "Improving ZHA network stability"
tags: ZHA zigbee
excerpt: An overview of my attempts to stabilize ZHA
slimme_lezer_gallery:
  - url: /assets/images/zha/slimmelezer1.jpeg
    image_path: /assets/images/zha/slimmelezer1.jpeg
    title: ""
  - url: /assets/images/zha/slimmelezer2.jpeg
    image_path: /assets/images/zha/slimmelezer2.jpeg
    title: ""
last_modified_at: 01-11-2025
---

# Update: I've switched to Zigbee2MQTT

First up: I no longer use Zigbee Home Automation (ZHA) in my setup, as I have migrated to Zigbee2MQTT. That network has now proven to be stable for me with 75+ devices. The most important takeaways are:

 - Use Zigbee 3.0 devices whenever possible.
 - Remove any older Xiaomi/Aqara devices from your network once they begin having issues.
 - Add more dedicated routers to your network, such as Sonoff ZBdongle-E Plus Zigbee 3.0 USB dongles flashed with router firmware.

 The blog post below is still useful though, so I've kept it.

# Changelog

- May 2025: Enabled firmware updates for IKEA devices.
- June 2025: ZHA network crashed, and controller migration
- Okt 2025: Deprecated article

# Situation

The ZHA network had trouble keeping battery-powered nodes online for a while. [![Xiaomi presence sensor](/assets/images/zha/xiaomi-motion.webp){: .align-right width="10%"}](/assets/images/zha/xiaomi-motion.webp) Especially the various Xiaomi sensors have issues staying connected and require periodic re-pairing. These are known to have trouble with certain routers, and not all Xiaomi sensors had issues. They also had issues on the deCONZ network occasionally. So initially it seemed to be mainly related to those motion sensors.

I had also been seeing the following log message for a while, but it disappeared over time.

```
Zigbee channel 24 utilization is 99.52%!
```
Until now I was getting away with re-pairing a sensor when needed. It didn't happen often enough to warrant completely overhauling the network (migration to Zigbee2MQTT for example) and I had monitoring set up for devices going offline, so I was usually the first in the family to know when a sensor had issues.

Meanwhile, I had been working for 2 years on migrating from deCONZ to ZHA and I really wanted to finish that at some point. But to do that, the ZHA network needed to be more stable first.

There's plenty written on the internet about getting a Zigbee network stable. A forum post I found particularly useful was [this one by Hedda](https://community.home-assistant.io/t/zigbee-network-optimization-a-how-to-guide-for-avoiding-radio-frequency-interference-adding-zigbee-router-devices-repeaters-extenders-to-get-a-stable-zigbee-network-mesh-with-best-possible-range-and-coverage-by-fully-utilizing-zigbee-mesh-networking/515752). Reading through it, I thought I had already tried everything. USB2 extension cable anyone? Or the [channel overlap diagram between Zigbee and WiFi](https://www.metageek.com/training/resources/zigbee-wifi-coexistence/) from Metageek? Over the years [the ZHA integration documentation page](https://www.home-assistant.io/integrations/zha) has been significantly expanded and contains lots of useful information.

[![Zigbee channel overlap](/assets/images/zha/zigbee-channels.png){: .align-center width="60%"}](/assets/images/zha/zigbee-channels.png)

The next step would be considering a migration to Zigbee2MQTT, which meant going down a rabbit hole in the world of Zigbee firmwares and chipsets. I wasn't really in the mood for that yet. In fact, in recent years I've been trying to reduce complexity. Think for example of phasing out InfluxDB and Grafana because Home Assistant's energy dashboard and statistics storage have improved so much. So if I have to choose between deCONZ, ZHA and Zigbee2MQTT, ZHA would be my preference.

# Moving the Coordinator

In ZHA you can download "Diagnostics". [![Download diagnostics](/assets/images/zha/diag.png){: .align-right width="350"}](/assets/images/zha/diag.png) In the JSON you get, you'll find an energy scan per Zigbee channel. This works much better than setting your own WiFi and Zigbee channels to not overlap using the diagram above. After all, you also have neighbors and other sources of interference. As was evident from my energy scan. Of course, I had already tried putting the USB stick higher in the meter cabinet, as far away as possible from other equipment. But the meter cabinet remained a problem, so it was time to move things from the meter cabinet to the attic.

```json
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

I moved the server to the attic, and the energy scan already looks much better.

I hadn't used ZHA over-the-air firmware upgrades for my Zigbee devices before, since the UI shows a big warning that this requires a stable network. At this point I decided to try it, and it worked really well for 6-7 devices (battery powered)! One device needed a couple of attempts, but otherwise no issues. It seems we're making progress!

# Side quest: P1 over Ethernet

The only reason why my small server needs to be in the meter cabinet is because it's connected to the P1 port of the smart meter. Nowadays there are Ethernet solutions available for this. For example [this one from Marcel Zuidwijk](https://www.zuidwijk.com/product/p1-reader-ethernet/). 

<div style="width: 50%;">
{% include gallery id="slimme_lezer_gallery" %}
</div>{: .align-center}
It's 5 euros cheaper than the [ESPHome-based version](https://www.zuidwijk.com/product/slimmelezer-wt32-eth01/) and in hindsight I probably should have gone for that second one. The first one contains some Chinese software, and I personally prefer open firmware. Anyway, I put it on its own VLAN that I also use for Chinese robot vacuum cleaners for example, and it works perfectly :).

# Measuring Channel Energy Over a Longer Period

After moving the server to the attic, the channel energy values were lower, but fluctuated. Because of this, it wasn't immediately clear to me which channel would be smart to select. To properly determine which channel number would be smart to use, we actually need to know these energy values over a longer period of time.

With the following YAML configuration you create a REST sensor in Home Assistant that calls its own API to make these energy levels available in a sensor. Look up your `config_entry` by examining the URL in your web browser when visiting your ZHA integration. You can create your `Bearer token` in your Home Assistant user under "Security" and then "Long-lived access tokens".

In my environment it seemed like Home Assistant, ZHA and/or the coordinator briefly blocks when it collects the diagnostics. The following code does this every minute. While this runs it can therefore cause some delay on the network each time it retrieves the diagnostics.
{: .notice--warning}

```yaml
{%- raw -%}
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

Then you can display this in Grafana for example. This makes it easy to determine which channel number works well.

[![](/assets/images/zha/zha_energy_grafana.png){: .align-center width="70%" }](/assets/images/zha/zha_energy_grafana.png)

# Adding a Router

But wait, I have enough routers... right? Every mains-powered node acts as a repeater for your mesh. Yet one router is not the same as another. In the network overview in ZHA, many red lines were visible. This was especially the case with the [IKEA Trådfri LED strip drivers](https://www.ikea.com/nl/nl/p/tradfri-driver-voor-draadloze-besturing-smart-grijs-60342656/).

[![](/assets/images/zha/smlight_snlzbbnlziets-06m.png){: .align-center width="50%" }](/assets/images/zha/smlight_snlzbbnlziets-06m.png)

By now, a very popular device has entered the market from SMLight, the [SLZB-06M](https://smlight.tech/product/slzb-06m/). My main reason for using this is the signal strength this is capable of. If [this YouTuber](https://www.youtube.com/watch?v=QckXMMxDF0k) can cover 80 meters with it, it should work well in my home too.

I'm a huge fan of this device. It can be powered by USB-C or PoE, manufactured in Ukraine, costs only 35 euros on AliExpress, and contains very good firmware (Home Assistant support out-of-the-box).

[![](/assets/images/zha/snlzbbnldinges_ui.png){: .align-center width="90%" }](/assets/images/zha/snlzbbnldinges_ui.png)

On the hardware side, it uses an ESP32, has optional support for ESPHome if you want, and the Zigbee chip is the same one used in the Sky Connect / ZBT-1 (Silicon Labs EFR32MG21). You can flash your own firmware of choice on the Zigbee chip, or choose from the latest router or coordinator firmware from Silicon Labs. Even Matter-over-Thread support is available. It's also easy to migrate from the ZBT-1 to the SLZB-06M with full support from Home Assistant. 

This device comes in several other variations, like the SLZB-06 (without the M) that contains a Texas Instruments CC2652P chipset that's been well supported in Zigbee2MQTT for years. But since early 2025, Zigbee2MQTT also has promoted support for the Silicon Labs chipset from experimental to officially supported. 
{: .notice--warning}

# Enable Source Routing

Update June 2025: My Sonoff TRVZB TRVs spam the logs with `ZIGBEE_DELIVERY_FAILED: 3074` messages, but only the first minute or two. They work fine after that.
{: .notice--warning}

ZHA uses something called Table Routing to determine routes in the network. This relies on router devices in your network to maintain a table of nodes they can see. Since it's generally known that not every manufacturer implements this the same way and some simply don't work well, you're basically asking for trouble. Combining old Hue lamps with Xiaomi battery-powered sensors? Guaranteed issues.

The alternative is Source Routing (this is also used by default in Zigbee2MQTT). Here, the coordinator determines the route through the network. This also results in less broadcast traffic.

Cem Basoglu wrote a [fantastic article about this](https://meshstack.de/post/home-assistant/zigbee-table-routing-vs-source-routing-zha/), and enabling it is super simple. Also, little can go wrong. If the network doesn't stabilize after a few hours and re-pairing difficult sensors doesn't work, you just turn it off again.

```yaml
  zha:
    zigpy_config:
      source_routing: true
```

After enabling it, it can take several hours before routers stop updating their tables and the network really starts relying on Source Routing. So expect nodes to become unreachable for a while, or sometimes require re-pairing to work properly on the network again.

# Zigbee Traffic Sniffing

Sensors still kept falling off the network occasionally. Sometimes it was just an empty battery :facepalm:, but often problematic nodes that kept dropping off.

The same Cem wrote another [fantastic article about how to sniff network traffic](https://meshstack.de/post/home-assistant/zigbee-sniffer-guide/), allowing you to see exactly where things go wrong. By purchasing another SMLight SLZB-06M, installing [ember-zli](https://github.com/Nerivec/ember-zli) (see Cem's article and the project's README), and entering some encryption keys from my network in Wireshark, I quickly had Wireshark seeing Zigbee traffic on my network.

I took a Xiaomi sensor that Home Assistant had marked as unavailable. Instead of re-pairing it as usual, I checked with Wireshark what was going on. (The node's address can be found in Home Assistant under the device as NWK address). First, I wanted to see if I could spot anything on the network by waking up the sensor. It was a vibration sensor, but tapping it did nothing. Briefly pressing the button did spawn some traffic on the network.

![](/assets/images/zha/ikmoetjounie.png){: .align-center width="90%" }

OK, first packet is a Rejoin request. Cool. However, there's another node on the network that clearly isn't friends with that sensor anymore... Leave? Come on, be nice...

That other node turned out to be an Innr E14 bulb... on the other side of the house? That node did have issues before, and restarting it (disconnecting power to the bulb) has helped more than once to get other sensors back. So, I restarted the bulb, pressed the button on the Xiaomi vibration sensor again (so, no resetting), and lo and behold!

![](/assets/images/zha/ohja-tochweltoch.png){: .align-center width="90%" }

This time the other SLZB-06M (acts as router in the network) responds to the Rejoin request, and the sensor manages to rejoin the network without a reset / re-pair! 

Great! So this network sniffing is useful in finding problematic routers in the network. I made a mental note to replace that light bulb in the future.

# April 2025: Current Situation and Next Steps

I now have two SLZB-06Ms in my house. One as a router, and the other as a sniffer. Eventually I want to migrate the Sky Connect / ZBT-1 that currently functions as coordinator to one of these, because they're so much easier to place around the house with PoE. I'm also going to replace problematic routers with better routers (that Innr lamp), because I currently think this is the main cause of sensors disappearing now and then. Additionally, there are sometimes sensors that Home Assistant marks as unavailable, but are actually still working. These are moisture and motion sensors that reach Home Assistant fine when detecting something and come back online. I'm not sure yet what to do with these.

At this point, however, I've learned something interesting, it works stable enough and there are clear diagnostic steps to take when problems occur. For now, this is a solved problem.

# May 2025: OTA Updates for IKEA Devices

I discovered that zigpy by default [doesn't have firmware updates enabled for a lot of device vendors](https://github.com/zigpy/zigpy/wiki/OTA-Configuration). Since I have a lot of IKEA devices acting as routers, I enabled updates for them. It then takes a few days for ZHA to recognize updates being available for individual devices. After a few days, almost all of my IKEA devices received and installed updates.

```yaml
  zha:
    zigpy_config:
      ota:
        extra_providers:
          - type: ikea
```

# June 2025: ZHA Crash and the Move to Zigbee2MQTT

I've had two crashes this month, leading me to abandon ZHA and slowly migrate to Zigbee2MQTT for the next year or so.

The first crash looked like the known issue where some devices go offline, but now router devices are also affected. I've moved 8-10 devices (mainly Xiaomi battery powered devices) from the ZHA network to a newly created Zigbee2MQTT network using a PoE SMLight SLZB-06M as a coordinator. This stabilized the ZHA network again. Not sure if this is some maximum device limit from the ZHA network, or an overload of the routers. 

I've been moving every problematic device from the ZHA network to Zigbee2MQTT since then, effectively migrating most of the Xiaomi devices there. Some Xiaomi sensors still had difficulty maintaining connections, and I will be replacing them with Zigbee 3.0 alternatives. I'm mainly using Sonoff devices for that, specifically the [SNZB-03P](https://www.zigbee2mqtt.io/devices/SNZB-03P.html) for motion. I also saw more firmware updates available, so I will be moving from ZHA to Zigbee2MQTT slowly over the next year or so, and seeing if that stays stable. 

Tip: Be sure to enable the Availability extension (Settings -> Availability), otherwise you won't see when devices go unavailable in Home Assistant and the Zigbee2MQTT UI. Other than that, I've left everything at the defaults.
{: .notice--warning}

The second crash took the entire ZHA network down, and it only came back up once I completely power-cycled the server it runs on and/or took the SkyConnect USB stick (yes, I've still got the first edition :P) out of the USB port and reconnected it. Also, Proxmox looked like it got confused with the USB identifier for a Meshtastic node I hooked up to a USB port on that server, just for power (a Heltec V3). So I disconnected that. But even after that, it went down another time. This time, I migrated the SkyConnect to one of the SMLight SLZB-06Ms I had using [this awesome guide from Home Assistant itself](https://support.nabucasa.com/hc/en-us/articles/26123655295261-Migrating-an-existing-Zigbee-Home-Automation-ZHA-network). Total downtime was less than a few minutes. Awesome to see this migration working so perfectly!

Since this, the network has been stable again, but I will be moving to Zigbee2MQTT and abandoning ZHA. Zigbee2MQTT gives me more insight, like notifications of devices not following the Zigbee standard or having known issues, and more control over the Zigbee network. Also, there is this awesome log analyzer tool at [https://nerivec.github.io/z2m-ember-helper/](https://nerivec.github.io/z2m-ember-helper/) which helps with finding known issues in the network. 

That's it for now. More to come once I've got a few months or so experience with this.
