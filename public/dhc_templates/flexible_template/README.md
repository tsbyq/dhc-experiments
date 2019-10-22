How to customize chiller and boiler combinations and automatically generate plant loop for use with loadprofile:plant?
===
##Steps:
 1. Modify the numbers of chillers and boilers in the **in.idf** file

    For example, add more chillers and specify the priority with:
~~~
HVACTemplate:Plant:Chiller,
    Chiller No. 1,            !- Name
    ElectricReciprocatingChiller,  !- Chiller Type
    autosize,                !- Capacity {W}
    3.2,                     !- Nominal COP {W/W}
    WaterCooled,             !- Condenser Type
    1,                       !- Priority
    ;                        !- Sizing Factor
~~~

 2. Use **ExpandObjects.exe** to expand the modified **in.idf** file. This will generate a new **expanded.idf**
 
 3. Remove the zone fan coil objects in the **expanded.idf**
 
    * From
    * To
 
 4. Substitute the 
 
 5. Append the idf 
 

~~~
Some code
~~~
