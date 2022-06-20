const {expect} = require("chai");
const {
    convertCrystal
} = locklift.utils;

class Bank {
    constructor(bankContract) {
        this.contract = bankContract
        this.address = bankContract.address
    }

    static async fromAddress(addr) {
        const bankContract = await locklift.factory.getContract("SimpleBank")
        bankContract.setAddress(addr)
        return new Bank(bankContract)
    }

    async registerUser(user) {
        const accountAddress = await user.runTarget({
            contract: this.contract,
            method: 'registerUser',
            params: {
                send_gas_to: user.address,
            },
            value: convertCrystal(2, 'nano')
        })
        console.log(`Account registered with address ${accountAddress}`)
        return accountAddress
    }

    async getUserDataAddress(userAddress) {
        return this.contract.call({
            method: 'getUserDataAddress',
            params: {
                user: userAddress
            }
        })
    }

    async getEvents(eventName) {
        return this.contract.getEvents(eventName)
    }

    async getTokenWallet() {
        return this.contract.call({method: "tokenWallet"})
    }

    async withdraw(user, amount) {
        return user.runTarget({
            contract: this.contract,
            method: 'withdraw',
            params: {
                _amount: amount,
                _nonce: locklift.utils.getRandomNonce()
            },
            value: convertCrystal(5, 'nano'),
            tracing: true,
        })
    }

    async deposit({depositValue, userTokenWallet, userData, bankTokenWallet}) {
        await userTokenWallet.transfer(depositValue, this.address, undefined, true)
        const event = await this.contract.getEvents("Deposit")
        expect(Number(event[0].value.amount)).to.be.eq(depositValue)
        expect(await bankTokenWallet.balance().then(res => res.toNumber())).to.be.eq(depositValue)
        expect(await userData.getUserData().then(res => res.amount.toNumber())).to.be.eq(depositValue)
    }

    async burn(owner, burnFromAddress, amount) {
        return owner.runTarget({
            contract: this.contract,
            method: 'startBurn',
            params: {
                _targetUser: burnFromAddress,
                _amount: amount
            },
            value: convertCrystal(5, 'nano'),
            tracing: true,
        })
    }

    async sendToUser(owner,sendToAddress, amount) {
        return owner.runTarget({
            contract: this.contract,
            method: 'sendToUser',
            params: {
                _targetUser: sendToAddress,
                _amount: amount
            },
            value: convertCrystal(100, 'nano'),
            tracing_allowed_codes:{compute: ['null'], action: ['null']}

        })
    }
}

class UserData {
    constructor(userDataContract) {
        this.contract = userDataContract
        this.address = userDataContract.address
    }

    static async fromAddress(addr) {
        const userDataContract = await locklift.factory.getContract("UserData")
        userDataContract.setAddress(addr)
        return new UserData(userDataContract)
    }

    async getUserData() {
        return this.contract.call({
            method: 'getDetails',
        })
    }

    async getBalance() {
        return this.contract.call({
            method: 'amount'
        })
    }

    async getEvents(eventName) {
        return this.contract.getEvents(eventName)
    }

    async sendToUser(user, targetUser, amount) {
        return user.runTarget({
            contract: this.contract,
            method: 'sendToUser',
            params: {
                _targetUser: targetUser,
                _amount: amount,
                send_gas_to: user.address
            },
            value: convertCrystal(5, 'nano'),
            tracing: true,
        })
    }


}

const deposit = async (bank, bankTokenWallet) => {

}

module.exports = {
    Bank,
    UserData
}
