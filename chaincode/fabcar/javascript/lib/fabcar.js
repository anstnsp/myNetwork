/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Contract } = require('fabric-contract-api');

class FabCar extends Contract {

    async initLedger(ctx) {
        console.info('============= START : Initialize Ledger ===========');
        const cars = [
            {
                color: 'blue',
                make: 'Toyota',
                model: 'Prius',
                owner: 'Tomoko',
            },
            {
                color: 'red',
                make: 'Ford',
                model: 'Mustang',
                owner: 'Brad',
            },
            {
                color: 'green',
                make: 'Hyundai',
                model: 'Tucson',
                owner: 'Jin Soo',
            },
            {
                color: 'yellow',
                make: 'Volkswagen',
                model: 'Passat',
                owner: 'Max',
            },
            {
                color: 'black',
                make: 'Tesla',
                model: 'S',
                owner: 'Adriana',
            },
            {
                color: 'purple',
                make: 'Peugeot',
                model: '205',
                owner: 'Michel',
            },
            {
                color: 'white',
                make: 'Chery',
                model: 'S22L',
                owner: 'Aarav',
            },
            {
                color: 'violet',
                make: 'Fiat',
                model: 'Punto',
                owner: 'Pari',
            },
            {
                color: 'indigo',
                make: 'Tata',
                model: 'Nano',
                owner: 'Valeria',
            },
            {
                color: 'brown',
                make: 'Holden',
                model: 'Barina',
                owner: 'Shotaro',
            },
        ];

        for (let i = 0; i < cars.length; i++) {
            cars[i].docType = 'car';
            await ctx.stub.putState('CAR' + i, Buffer.from(JSON.stringify(cars[i])));
            console.info('Added <--> ', cars[i]);
        }
        console.info('============= END : Initialize Ledger ===========');
    }

    async queryCar(ctx, carNumber) {
        const carAsBytes = await ctx.stub.getState(carNumber); // get the car from chaincode state
        if (!carAsBytes || carAsBytes.length === 0) {
            throw new Error(`${carNumber} does not exist`);
        }
        console.log(carAsBytes.toString());
        return carAsBytes.toString();
    }

    async createCar(ctx, carNumber, make, model, color, owner) {
        console.info('============= START : Create Car ===========');

        const car = {
            color,
            docType: 'car',
            make,
            model,
            owner,
        };

        await ctx.stub.putState(carNumber, Buffer.from(JSON.stringify(car)));
        ctx.stub.setEvent("create", owner.toString()); 
        console.info(`owner:${owner}`)
        console.info('============= END : Create Car ===========');
    }

    async createCarObj(ctx, param) {
        console.info('============= START : Create Car Obj ===========');
        
        console.log(`param : ${param}`); // {"carNumber":"CAR777","color":"red","make":"문수","model":"제네시스","owner":"문수네"}

        console.log(`JSON.stringify(param) : ${JSON.stringify(param)}`);
        console.log(`param.carNumber: ${param.carNumber}`)

        const obj = JSON.parse(param); 
        console.log(`obj : ${obj}`)
        console.log(`obj.carNumber: ${obj.carNumber}`)
        // const car = JSON.parse(param); 
        // console.log(`carNumber : ${car.carNumber}`)
        //데이터값은 { } 오브젝트를 stringify 해서 버퍼로 바꿔서넣음. 
        await ctx.stub.putState(obj.carNumber, Buffer.from(JSON.stringify(obj)));

        ctx.stub.setEvent("createObj", Buffer.from(JSON.stringify(obj)));

        console.info('============= END : Create Car Obj ===========');
    }

    async insertList(ctx, param) {
        console.info('============= START : insertList ===========');
        console.log(`param: ${param}`)
        const carList = JSON.parse(param); 

        const carList2 = carList.list; 
        console.log(`carList: ${carList2}`); 

        for(let i=0; i<carList2.length; i++) {
            
            await ctx.stub.putState(carList2[i].carNumber, Buffer.from(JSON.stringify(carList2[i])));
            console.info(`Added <--> `, carList2[i]);
            
        }

        
        ctx.stub.setEvent("list", Buffer.from(JSON.stringify(carList))); 
        console.info('============= END : insertList ===========');
    }

    async queryAllCars(ctx) {
        const startKey = 'CAR0';
        const endKey = 'CAR999';

        const iterator = await ctx.stub.getStateByRange(startKey, endKey);

        const allResults = [];
        while (true) {
            const res = await iterator.next();

            if (res.value && res.value.value.toString()) {
                console.log(res.value.value.toString('utf8'));

                const Key = res.value.key;
                let Record;
                try {
                    Record = JSON.parse(res.value.value.toString('utf8'));
                } catch (err) {
                    console.log(err);
                    Record = res.value.value.toString('utf8');
                }
                allResults.push({ Key, Record });
            }
            if (res.done) {
                console.log('end of data');
                await iterator.close();
                console.info(allResults);
                return JSON.stringify(allResults);
            }
        }
    }

    async changeCarOwner(ctx, carNumber, newOwner) {
        console.info('============= START : changeCarOwner ===========');

        const carAsBytes = await ctx.stub.getState(carNumber); // get the car from chaincode state
        if (!carAsBytes || carAsBytes.length === 0) {
            throw new Error(`${carNumber} does not exist`);
        }
        const car = JSON.parse(carAsBytes.toString());
        car.owner = newOwner;

        await ctx.stub.putState(carNumber, Buffer.from(JSON.stringify(car)));
        ctx.stub.setEvent("change", Buffer.from(JSON.stringify(car))); 
        console.info('============= END : changeCarOwner ===========');
    }
    async createPrivData(ctx) {
        console.info('============= START : createPrivData ===========');
        const transMap = await ctx.stub.getTransient(); 
        console.info(`transMap : ${transMap}`);
        console.log(`transMap["car"]: ${transMap.get("car")}`)  //transMap["car"]: ByteBufferNB(offset=1215,markedOffset=-1,limit=1249,capacity=1249)
        console.log(`transMap.get("car").toString("utf8"): ${transMap.get("car").toString("utf8")}`)  //transMap.get("car").toString("utf8"): {"carNumber":"CAR111","price":444}

        const transientData = transMap.get("car").toString("utf8"); 
        const jsonData = JSON.parse(transientData); 

        console.log(`jsonData.carNumber: ${jsonData.carNumber}`);
        console.log(`jsonData.price: ${jsonData.price}`);


        // putPrivateData 인터페이스:    await ctx.stub.putPrivateData(collection, key, value));
        await ctx.stub.putPrivateData("collectionFabcar", jsonData.carNumber, Buffer.from(JSON.stringify(jsonData) ) );
   
        ctx.stub.setEvent("private", Buffer.from(JSON.stringify(jsonData))); 
        
        console.info('============= END : createPrivData ===========');
    }

    async queryPrivData(ctx, carNumber) {
        console.info('============= START : queryPrivData ===========');
        const privDataAsBytes = await ctx.stub.getPrivateData("collectionFabcar", carNumber); 

        if (!privDataAsBytes || privDataAsBytes.length === 0) {
            throw new Error(`${carNumber} does not exist`);
        }
        // const carAsBytes = await ctx.stub.getState(carNumber); // get the car from chaincode state
        // if (!carAsBytes || carAsBytes.length === 0) {
        //     throw new Error(`${carNumber} does not exist`);
        // }
        console.log(privDataAsBytes.toString());
        return privDataAsBytes.toString();
        console.info('============= END : queryPrivData ===========');
    }


}

module.exports = FabCar;
