---
title: "How to organize way too much YAML and why"
tags: 
 - YAML 
 - configuration 
 - over-the-top 
 - Home Assistant
excerpt: A deep-dive into my over-engineered Home Assistant YAML setup and what perks it gives me
last_modified_at: 13-12-2025
---

# Introduction

I've been using Home Assistant since 2018, and nowadays almost everything in my home is connected to it. I've always managed it using YAML files, which have now grown to about 12.000 lines across nearly 200 files. I still use the same approach as when I started, and if I were to begin again today, I would do it the same way. There is just something magical to changing code and having an effect in the physical world.

This post is my perspective as a software developer on managing Home Assistant configuration as code. It’s quite a read, but I hope it provides you with useful pointers for thinking about the logic you implement, and insights into how to use the tools Home Assistant provides to help organize it.

## A bit of community history

If you browsed the forums around 2019/2020, you would have found a group of users who strongly preferred to use YAML for configuring Home Assistant, instead of the user interface. And with good reason, as YAML had been the primary way to configure Home Assistant for years. However, the ability to set up integrations using YAML was being gradually phased out, which created uncertainty about YAML's future in Home Assistant.

To some extent, this strong preference for YAML still exists, although it is less polarizing now than it used to be. The discussion largely settled down after [Home Assistant made its long-term vision for YAML explicit](https://www.home-assistant.io/blog/2020/04/14/the-future-of-yaml/), allowing YAML to find its place within the ecosystem.

YAML is here to stay (whew...), and it serves a specific purpose in Home Assistant. Understanding that purpose helps you know where its strengths lie and how best to use it.

## Why do I use YAML?

Back in 2018, I started with building a solid foundation to run Home Assistant on top of. I wanted to tackle that first, as building automations meant my day-to-day life will start depending on that. SDcard failures were all too common at the time, and nothing breaks down your partner's approval for your hobby faster than stuff suddenly breaking. Think of an approach like running Home Assistant as a virtual machine on top of a hypervisor, to get flexibility in moving it around, creating snapshots before making big changes, etc. Remember, back then Home Assistant OS was called hassio, and was only just released. It didn't feature backups yet, for example.

The classic way is to backup and restore the entire machine. But, in IT automation, an anything-as-code declarative approach was all the rage (think Puppet, Ansible and Chef). I wanted this declarative approach to home automation. Think of the classic pet vs cattle comparison. With a pet, you nurse it back to health (VM is a black box, you only have one, it evolves over time, you fix it up, etc.), but with the cattle approach, if it misbehaves, you kill it off and start with a new instance. The system is more transparant and deterministic.

Restoring from a declarative setup involves downloading a new copy of Home Assistant and handing it your config files. These files contain your house logic. The Home Assistant instance is stateless: If something gets screwed up or corrupted, you always start again clean. Reproducing and narrowing down issues becomes way easier. Also, these config files are human-readable and mutable. Keeping these configuration files in a version control system like git for example, gives some other nice additional features, like traceability to changes. 

Of course, this declarative approach can be combined with traditional means like snapshots and backups, but having these options available allows you to play with Home Assistant, break it, test stuff, and if you don't like it, revert it. All the while having tracability and thus being able to revert parts of it. This made a lot of sense for me when something is both a hobby, and at the same time an entire household needs to be able to depend on it. I don't want to spend 3 hours diagnosing why some sensor doesn't work while we're trying to get out the door with two young kids.

## Developments since then

Years later, now in 2025, this vision of YAML still applies, and Home Assistant still officially supports YAML as a first-class citizen, even though developments the past years make it look like the UI is where all the priority is. There is just a lot to gain in the UI area, where the YAML side of things looks to be mature and stable. Even more so, the whole UI relies on YAML, as it's built on top of it. In practically every place, you can open up a menu and switch to a YAML editor, make changes there, and even switch back, and the UI will populate according to what you changed! How awesome is that?

The most important things that changed from a declarative setup perspective:
- Their approach to setting up integrations, and how/where the access tokens or credentials for those are stored: This piece of the configuration is no longer meant to fit in the above declarative approach. Setup is almost always in the UI, and any stored credentials are not meant to be part of the state of the installation.
- Long-term storage has gotten so much better with their introduction of a statistics storage. I've got around 3600 entities and 4 years worth of statistics and 4 days of history stored in just 2,7GB. Combined with it being very stable for the last years, I've got less of a use case for storing historic data outside of the Home Assistant instance. For the sake of simplicity and reducing maintenance burden, this is now best hosted as part of Home Assistant itself, instead of let's say a separate PostgreSQL store. You can still configure InfluxDB for example, but its purpose is more to integrate with an external system, than it is to use that as the primary store for long-term statistics.

These two changes make it necessary to see the Home Assistant instance no longer as an ephemeral stateless instance, being able to be rebuilt from some declarative set of configuration files, but as something needed to be backed up and restored. This is further confirmed by the now present backup system inside Home Assistant itself. This approach works well when using dedicated hardware to run Home Assistant (Green for example). This is very user-friendly to setup, and the whole setup now can be regarded as an appliance. Think Hue bridge for example.

From a purists perspective wanting control and a reliable system, this approach doesn't scratch my itch. It now act like a black box. Restoring a backup is more of a "keeping-your-fingers-crossed", than starting from a blank slate (destroying a potentially tainted state) and loading a set of known good configuration files in. It is still possible to do, but you would need to set up a lot of integrations again manually. Restoring state from a backup first has the preference now.

[![](/assets/images/yaml/integrations.png){: .align-center width="80%" }](/assets/images/yaml/integrations.png)
<p align="center" width="80%">
  <em>Nice to be able to restore this all in one operation</em>
</p>

Fun fact: Since the OS is based around docker, the backup contains only your state and configuration of Home Assistant and all addons. It doesn't contain Home Assistant or any addon software. Only the reference to what versions you had running. Upon restore it downloads those versions again and feeds it your state and configuration. So, the underlaying technology is really sound, and the way they are marketing it as an appliance is a really conscious user-experience choice, and is very good to do from the perspective of adoption. This does make for a really reliable foundation in my opinion.
{: .notice--info}

## Is the YAML approach still valid in 2026?

While some of the benefits have changed, I believe there are still plenty of upsides to having your home automation configuration in YAML. Integrations setup and historic data (along with addons) is now handled using a backup mechanism of your own choosing, (VM snapshots, offsite VM backups, or the built-in provided mechanism), but this can still be combined with your YAML files.

So, the primary approach is now to regard the system as having state. But as far as building the logic for your home (scripts, scenes, automations, etc) you have the choice between:
- Using the UI to set these up, and regarding your configuration also as state, being automatically included in the backup you now already have, or;
- Still take the declarative approach, and push YAML to Home Assistant with a system of your choice.

For me, these are some of the benefits of still using YAML:
- Keeping track of changes in git allows for traceability and a sort of 0-effort documentation on why stuff works the way it does.
- It allows for any arbirtary additional information to be added in the form of comments. This is filtered out when working with YAML in the UI.
- I rely on [Packages](https://www.home-assistant.io/docs/configuration/packages/) heavily. Building larger features consisting of multiple automations and helpers is way easier if you are able to bundle them together in packages. The UI lacks support for packages or any support for keeping these together.
- Using something like VSCode or Cursor allows for easy search-and-replace, refactors and checking of references. There are a lot of free perks you get by using a proper editor. It also offers a way better complete overview than having to click around. Everything is just a few keystrokes away.
- It allows to try out different things at the same time, even though you're working on the "production environment", by rolling it back if you don't like it.

# Organizing YAML

As your pile of YAML code grows, you'll want to organize it in some maintainable way. In this chapter, I'll go through my reasoning and end up on how I maintain it.

## Splitting up `configuration.yaml`

There are plenty of examples to find where one does [something like this](https://www.home-assistant.io/docs/configuration/splitting_configuration/), or using [any of the](https://www.home-assistant.io/docs/configuration/splitting_configuration/#advanced-usage) `include_dir_list` or friends.

```yaml
automation: !include automation.yaml
zone: !include zone.yaml
sensor: !include sensor.yaml
switch: !include switch.yaml
device_tracker: !include device_tracker.yaml
```

The downside of this, however, is that you'll still end up with configuration scattered around the place when building advanced features. This is because you'll build those features consisting of multiple integrations (input_booleans, automations, scripts), which all combine to control your heat pump, bathroom fan, etc.

## Packages to the rescue!

Packages do roughly the same as root-level `!include`s, but on a level higher.

> [Packages](https://www.home-assistant.io/docs/configuration/packages/) in Home Assistant provide a way to bundle configurations from multiple integrations.

Setting the following in `configuration.yaml`

```yaml
homeassistant:
  packages: !include_dir_merge_named includes/packages
```

Allows for the following directory structure:
```
config/
├── configuration.yaml
└── includes/
    └── packages/
        ├── heatpump_thermostat.yaml
        ├── bathroom_fan.yaml
        └── living_room_lightning.yaml
```

`bathroom_fan.yaml` for example then contains something like:
```yaml
bathroom_fan:
  template:
    - sensor:
        - unique_id: bathroom_fan_current_position  
          ...
  script:
    bathroom_fan_do_some_thing:
      sequence:
        - ...

  automation:
    - alias: bathroom_fan_automatic
      ....
```

This allows you to keep everything around a functionality together. Think of a structure like

```
config/
├── configuration.yaml
└── includes/
    └── packages/
        ├── global/
        │   ├── house_status.yaml
        │   └── christmas.yaml
        ├── areas/
        │   ├── bedroom.yaml
        │   └── living_room/
        │       ├── curtains.yaml
        │       ├── fireplace.yaml
        │       └── speakers.yaml
        ├── tools/
        │   ├── ikea_light.yaml
        │   └── zwave.yaml
        └── integrations/
            ├── meshtastic.yaml
            ├── recorder.yaml
            ├── watermeter.yaml
            └── influxdb.yaml
```
 
## Editing and shipping the configuration files

I'm a software developer (nah, you don't say...), and as such I adopted a few creature comforts into to how I maintain these configuration files: Using the Git Server on a Synology NAS, and a proper code editor on my laptop, I get version control, syntax highlighting, syntax checking, etc. ([Tnx for the awesome code server!](https://github.com/keesschollaart81/vscode-home-assistant))

To ship the configuration files to my Home Assistant, I installed the [community SSH addon](https://github.com/hassio-addons/addon-ssh) into Home Assistant, and use an ansible playbook to push these over SSH to the Home Assistant instance. This ansible part is pretty thin, and could also have been a simple shell script with rsync, but I'm using ansible for a few other purposes anyway.

Again, recovery is in the back of my mind, so using an editor which supports [devcontainers](https://containers.dev/), allows to be up-and-running quickly whenever I need to re-setup the laptop. Devcontainers use configuration files inside the git repository to build a container used by the code editor. So, no matter which tools/toys/complexity I add, the setup stays the same: Checkout the git repo, install and open up in my editor of choice, and it sets up all dependencies I need, like ansible.

Alternatively, one can use the Studio Code Server addon, to run a Visual Studio Code instance inside Home Assistant, and initialize a git repo in there. But I find that it further blurs the lines of the concepts above, where state is separated from configuration.

## Structuring the packages

You'll notice I've made a few directories in the `includes/packages` directory. `areas` follow the physical layout of my house, where `integrations` separates the packages over a different axis. `tools` and `global` hold packages which multiple other packages depend on.

Each file in those directories have one or more package names as the root-level key. This is because I'm using `!include_dir_merge_named` in `configuration.yaml`. The package name is prefixed by their file location, because these need to be unique.

```yaml
area_bathroom_fan_status:
  template:
    - sensor:
        - unique_id: bathroom_fan_current_position
          ...

area_bathroom_fan_automatic:
  automation:
    - ...

area_bathroom_fan_control:
  script:
    area_bathroom_fan_control_set_step:
      fields:
        step:
      sequence:
        ...
```

This is a nice middle-ground between splitting the fan logic between multiple files or in a single file. This way, you keep it together, but are able to segregate it a bit, making the file logical/easy to read. For example keeping all low-level relay control at the bottom of the file, while another package in the same file handles a higher abstraction layer.

# Abstraction, interfaces and implementation

This is where we'll get into the contents of the `tools` and `global` directories in my setup. I'll admit this goes more into software development aspects, but these are good concerns to keep in your mind for larger setups. The more (advanced) features your build, the more YAML you'll end up with, the more important it is to have a maintainable pile of files. These concepts allow you to keep a clear separation of concerns between them and keep it maintainable, instead of becoming a big spaghetti bowl of tied together logic.

For example: You have a curtain in the living room, but also the upstairs hallway lights, along with a few other places, which need to adapt to light conditions: In this case, you abstract away the light conditions into a separate package

```yaml
{%- raw -%}
global_outdoor_light:
  template:
    - sensor:
        name: global_outdoor_light_level
        unique_id: global_outdoor_light_level
        state: "{{ ... }}"
{% endraw %}
```

The sole purpose of this package is to expose a sensor entity to the rest of the system. Its value also being well-defined, for example only being `day`, `dusk`, `night`, or a level between 0 and 100.

This way, other `area`-packages easily check if the `sensor.global_outdoor_light_level` is above or below a certain value for a period of time, resulting in a nicely synchronized closing of all screens and curtains across the house :P. Even better yet, to prevent having some clunky logic in triggers and conditions with these timings, you can provide helper entities like the following. This makes it really clean for those other packages to use this information.

```yaml
{%- raw -%}
  template:
    - binary_sensor:
        name: global_outdoor_light_dusk_2m
        availability: "{{ states('sensor.global_outdoor_light_level')|is_number }}"
        state: "{{ states('sensor.global_outdoor_light_level') < 30 }}"
        delay_off: { minutes: 2 }
{% endraw %}
```

Do this for a lot of things, like outside temperature, but also for virtual states, like if "people are home" or a generic "house status" `input_select` entity

```yaml
global_house_status:
  input_select:
    house_status:
      name: House status
      options: [Sleep, Home, Guests, Away, Vacation]
```

This allows for something called "loose coupling": The possibility to change one part of the system without having to change the other, by introducing a standardized interface to a set of shared information.

Be sure to define some of the more vague statuses, like `Guests`: For example for me, it means: Unidentified people are detected in the house, while all other identifiable aren't (me and my wife). This is used for people babysitting the kids for example. This makes it clear for the other packages where it can be used.

You don't need to abstract away everything at the initial setup, and I would recommend against going that far, as it adds a lot of layers not serving any immediate purpose, but when you find yourself having to search-replace stuff, you might as well create an abstraction layer and introduce a separate package. 

## Example: Determining outside light conditions

This clear abstraction and being aware of interfaces (the entities a package exposes and uses) also leaves nice options for implementations. For example, the global light levels: Most of the time, I use my solar panels' power delivery as the biggest light-sensor I have in my house. But there are a few situations where that doesn't work: For example when there is snowfall, or when you're actively reducing the power output of the solar panels when your energy buffering options are full, to prevent racking up costs on your energy bill (yes, in the Netherlands, depending on the contract your have, there are costs to transferring energy to the grid).

Having multiple implementations for the outdoor light level for example, allows me to switch between them in case where the primary doesn't work using a single `input_select` entity. I have one rudimentary one using the built-in `sun.sun`, or a mock, allowing to explicitly set the level for debugging. I can even try to assess when one doesn't work, and switch to another. Also: Indoor light sensors are a good idea.

## Example: Outdoor temperature

Another simpler example: In the past I've used an online integration from AccuWeather, relying on the internet to get the outdoor temperature. Having an abstraction for this allows me to put a temperature sensor in the backyard, after a few days compare the results of the two, and if close enough, I just change the package responsible for determining the outdoor temperature, to now read from that sensor instead of the AccuWeather integration.

## Example: HAL's

You'll recognize this term from the operating systems realm: The Hardware Abstraction Layer. I can hear you saying "What? Isn't Home Assistant meant to solve this problem? Like `light.turn_on` works regardless if that light is connected over Hue, Zigbee or Zwave?". Are you sure?

- Depending on the device, it will either turn on to the last set brightness, or some preconfigured value.
- Ikea light generally don't accept `brightness` and any of the `*_color` attributes in a single `light.turn_on` call.
- Buttons? They fire a `zha_event` in ZHA, or have an event entity under Zigbee2MQTT if you use that feature. Zwave also has its own events. Even within the same network stack, button events aren't standardized. Yes, Home Assistant does some nice efforts in the UI, but I find that these don't translate well into readable YAML. 

Especially if part of your hobby is to mix and match various technologies and vendors (I've got roughly 7 networks/platforms: Wifi/Ethernet, Hue, Zigbee2MQTT, ZWave, Bluetooth/BLE, RFLink, ESPHome), this becomes a headache pretty quickly after the initial fun wears off, as you'll end up constantly asking yourself which device is on which network, and which event it throws.

To bring maintainability and the fun of the hobby back at the same time, let's introduce some sanity into this mess: Hardware Abstraction Layer. It's basically a continuation of the above subject: The separation of concerns. This time, specifically for hardware quirks.

Take for example:

```yaml
{%- raw -%}
automation:
  - alias: living_room_shortcuts_translator
    id: living_room_shortcuts_translator
    use_blueprint:
      path: mkarnebeek/zigbee_ecodim_z2m_buttons.yaml
      input:
        event_entity: event.living_room_shortcuts_action
        script: script.living_room_shortcuts

script:
  living_room_shortcuts:
    mode: parallel
    sequence:
      - if: "{{ action == 'row_1_left_click' }}"
        then:
          ...
      - if: "{{ action == 'row_2_right_hold' }}"
        then: 
          ...
      ...
{% endraw %}
```

The first bit is an automation for a specific zigbee remote I placed at the wall. That just happens to be connected to the Zigbee2MQTT network. So, for that I use the Zigbee2MQTT button translator blueprint. Its job is to translate Zigbee2MQTT-specific button events for that device into a script call, passing a (for me) "standardized" `action` argument.

Now, if I move that button to a different zigbee network (I also had ZHA running previously) or replace it with a Zwave remote, I just need to update the first bit, utilizing a different blueprint. Since the inputs to the blueprint are clear, the blueprint itself handles the hardware-specific quirks, I can stay in my functionality-mindset, and not have to think about syntax or hardware specifics. 

Of course, you can do the same using events, or passing the actions as part of the blueprint arguments, etc. But the idea is the same: Separate hardware implementation from "business logic".

When working on functionality, I can keep working on functionality. When working on migrating some network, I can stay focused on that, without being distracted by what logic it covers. This brings focus and maintainability.

## Events

In general, template sensors, `input_select`s and `input_boolean`s for example can define a virtual **state**, like we discussed above with the `house_status`. In this example, they can store the state of the kids sleeping/awake, where events are for **occurrences**, like the kids alarm clock or a smoke alarm going off. These do blur a bit though, as the state transitions can perfectly fine be used as automation triggers. So, sometimes you'll find yourself "upgrading" an event to a state entity. 

What they have in common is that you can think of them as a standardized piece of information in your smart home which other areas of your smart home can act upon.

## Blueprints

Blueprints in Home Assistant are a kind of "template" automations. You define logic (triggers, conditions, actions) once and can create automation "instances" based on this blueprint. Blueprints can be created for automations. But did you know you can also create them for scripts? And even templates? Yup, you can create a single script or template blueprint which you can then instantiate multiple times, and thus share logic. 

I expect blueprints to add support in the future for other integrations. Keep your eyes open for features being added here! Maybe even packages? That would solve the issue of only being able to define a single entity per blueprint. 

## Example: Automation blueprints

I use this to standardize behavior for every light in my living room. Think of behavior like override support: Home Assistant normally controls the light by rolling out scenes through the day, and that's nice. But if a human touches something, the human is always right. If that happens (either via a button on the wall, or via the Home Assistant user interface), then Home Assistant shouldn't touch the light for a while. For example until the next `input_select.house_status` change or for an x amount of hours. Or handling turning a few lights red as an alert that one of the kids is out of bed.

Create a few of these as variants, like condition lights (distinction between a part of the room having presence, or the TV being on or off), and you have yourself a nice place to maintain all logic for all living room lights.

The only downside is that a single blueprint can only define a single automation. Luckily Home Assistant has plenty of support for trigger ID's and variables it can set, and you can encompass a lot of logic in a single automation.

```yaml
{%- raw -%}
trigger:
  - platform: ...
    variables:
      user_triggered: true
      condition: "{{ ... }}"
      activate_override: true
  ...
variables:
  override_active: "{{ is_state('timer....', 'active') }}"
condition:
  - "{{ condition if condition is defined else true }}"
  - "{{ user_triggered or (apply and not override_active) }}"
action:
  - action: scene.apply
    ...
  - if: "{{ activate_override }}"
    then: 
      action: timer.start, 
      target: 
        entity_id: ...
{% endraw %}
```

# Some other interesting concepts 

I don't use these as widespread as the examples above (yet), but they do offer interesting takes on solving logic organization challenges.

## Script return variables

When you [explicitly stop a script](https://www.home-assistant.io/docs/scripts#stopping-a-script-sequence), you can pass a set of variables back to the code that called the script.

```yaml
{%- raw -%}
# script
sequence:
  - variables:
      result:
        value: "{{ some_template }}"
  - stop: "Done"
    response_variable: result

# caller
action:
  - service: script.my_script
    data:
      some_input: "foo"
    response_variable: my_result
  - service: notify.notify
    data:
      message: "{{ my_result.value }}"
{% endraw %}
```

## Trigger based template entities supporting conditions and actions

Home Assistant supports template entities (sensors, binary_sensors, switches, even fans and alarm panels for example). At some point these were extended with [support for triggers](https://www.home-assistant.io/integrations/template/#trigger-based-template-entities): Instead of evaluating a piece of template code, they can refresh their state by reacting on triggers in the same way automations do. Later, they even further extended them by adding [`conditions:`](https://www.home-assistant.io/integrations/template/#trigger-based-sensor---using-conditions-to-control-updates) and [`actions:`](https://www.home-assistant.io/integrations/template/#trigger-based-weather---weather-forecast-from-response-data) support.

This roughly means you are able to set up a template entity and regard it as an automation. I haven't seen a use case for me yet in my setup, but it allows for combining logic which you otherwise would have separated.

Also: Remember, [this supports blueprints!](https://www.home-assistant.io/integrations/template/#using-blueprints) So, go crazy :P

# Testing

I have a second Home Assistant VM running purely for testing purposes. Building complex automations and testing their interactions is not something I'd like to do in the "production" setup. So, this VM is a testing ground where I can try out different approaches before applying them to the main Home Assistant instance.

Because of the way I separate the different parts (using the concepts I describe in this article), it makes it easy to feed these configuration bits with fake entities called mocks. Instead of setting up the SolarEdge integration, I load the following package, declaring the same entity_id's as the SolarEdge integration would.

```yaml
{%- raw -%}
mocking_solar_panels:
  input_number:
    solaredge_ac_output_power:
      min: 0
      max: 5500
      step: 100
    solaredge_dc_voltage:
      min: 0
      max: 1000
      step: 100
  
  template:
    - sensor:
        - name: "SolarEdge AC Output Power"
          unique_id: solaredge_ac_output_power
          default_entity_id: sensor.solaredge_ac_output_power
          state: "{{ states('input_number.solaredge_ac_output_power') }}"
          device_class: power
          state_class: measurement
          unit_of_measurement: "W"
        - name: "SolarEdge DC Voltage"
          unique_id: solaredge_dc_voltage
          default_entity_id: sensor.solaredge_dc_voltage
          state: "{{ states('input_number.solaredge_dc_voltage') }}"
          device_class: voltage
          state_class: measurement
          unit_of_measurement: "V"
{% endraw %}
```

This then exposes input_numbers I can slide around with in the UI, telling Home Assistant what my current solar production is, and I can then assess if the logic I build on top of that work as expected.

Deploying this YAML to the test Home Assistant works the same way as described in ["Editing and shipping the configuration files"](#editing-and-shipping-the-configuration-files) above. Once developed in the test instance, I manually move the files to a different directory in this Ansible setup, which then ships them to the main instance. Alternatively, when testing already deployed packages, I can instruct Ansible to automatically copy over these "main instance" modules (or entire directories) on deploy, so they are also deployed to the test instance. This allows me to choose what to run/test where, without duplicating files.

I can also update/upgrade that test instance first, to see if the new Home Assistant still works with my YAML. Only when that runs without errors for a few hours will I update the main instance. Due to the stability of Home Assistant and the greatly reduced breaking changes in the last year's releases, I haven't had a need for this flow, but it is still there if I want to use it, which is a really nice peace-of-mind thing to have :)

# AppDaemon

I can hear you saying: *"Are you crazy, doing all this in YAML? Haven't you heard of [AppDaemon](https://appdaemon.readthedocs.io/)?"* Yeah, I have, and in the old OpenZwave days (2021 and before) I've ran some monitoring apps in there (because at that time that's what it took to keep a zwave network stable...). But I have been getting away with solving this all in YAML, and they keep improving the YAML support, sooo... yeah. Also, there is some benefit in just having one system instead of multiple. 

Fun fact: Since I use [Elixir](https://elixir-lang.org/) at work, I have considered hooking those two together, but that hasn't evolved beyond a consideration (yet) :P
{: .notice--info}

# Closing

What? You're still here? Cool! :wave:

As I said at the top: I hope this provided you with some useful pointers for thinking about the logic you implement in your home, along with insights into how to use the tools Home Assistant provides to help organize it.

If you've enjoyed this article or it helped you in some way, please let me know by reaching out to me directly or below. 

