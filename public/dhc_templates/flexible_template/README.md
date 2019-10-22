How to customize chiller and boiler combinations and automatically generate plant loop for use with loadprofile:plant?
===
##Steps:
 1. Modify the numbers of chillers and boilers in the **in.idf** file ([example](example/in.idf))

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

 2. Use **ExpandObjects.exe** ([from EP](example/ExpandObjects.exe)) to expand the modified **in.idf** file. This will generate a new **expanded.idf**
 
 3. Remove the zone fan coil objects in the **expanded.idf** ([example](example/expanded.idf))
    * The following *branch* object and all the objects above it should be removed.
    ~~~
    Branch,
        Test room Heating Coil HW Branch,                        !- Name
        ,                                                        !- Pressure Drop Curve Name
        Coil:Heating:Water,                                      !- Component Object Type
        Test room Heating Coil,                                  !- Component Name
        Test room Heating Coil HW Inlet,                         !- Component Inlet Node Name
        Test room Heating Coil HW Outlet;                        !- Component Outlet Node Name
    ~~~
 
 4. Rename the branches in the demand side loop to match the load profile branches 
    * Substitute all the **"Test room Heating Coil HW Branch"** text to **"Hot Water Loop Load Profile Demand Branch"** 
    * Substitute all the **"Test room Cooling Coil ChW Branch"** text to **"Chilled Water Loop Load Profile Demand Branch"** 
 
 5. Append the **idf from step 4** to the **base.idf** file ([example](example/base.idf))
 

