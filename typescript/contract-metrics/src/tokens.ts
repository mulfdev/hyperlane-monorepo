import { mainnet } from './registerContext';
import config from './config';

import {
  AnnotatedTokenDeployed,
  TokenDeployedArgs,
  TokenDeployedTypes,
} from '@abacus-network/sdk/dist/abacus/events/bridgeEvents';
import {
  AbacusContext,
  queryAnnotatedEvents,
} from '@abacus-network/sdk/dist/abacus';
import { TSContract } from '@abacus-network/sdk/dist/abacus/events/fetch';
// import { ethers } from 'ethers';
import { uploadDeployedTokens } from './googleSheets';

type TokenDetails = {
  name: string;
  symbol: string;
  decimals: number;
};

export type Deploy = AnnotatedTokenDeployed & { token: TokenDetails };

async function getDomainDeployedTokens(
  context: AbacusContext,
  nameOrDomain: string | number,
): Promise<Deploy[]> {
  const domain = context.resolveDomain(nameOrDomain);
  const router = context.mustGetBridge(domain).bridgeRouter;
  // get Send events
  const annotated = await queryAnnotatedEvents<
    TokenDeployedTypes,
    TokenDeployedArgs
  >(
    context,
    domain,
    router as TSContract<TokenDeployedTypes, TokenDeployedArgs>,
    router.filters.TokenDeployed(),
    context.mustGetDomain(domain).paginate?.from,
  );

  return await Promise.all(
    annotated.map(async (e: AnnotatedTokenDeployed) => {
      const deploy = e as any;

      const erc20 = await context.resolveCanonicalToken(
        domain,
        deploy.event.args.representation,
      );
      const [name, symbol, decimals] = await Promise.all([
        erc20.name(),
        erc20.symbol(),
        erc20.decimals(),
      ]);

      deploy.token = {};
      deploy.token.name = name;
      deploy.token.symbol = symbol;
      deploy.token.decimals = decimals;
      return deploy as Deploy;
    }),
  );
}

async function getDeployedTokens(
  context: AbacusContext,
): Promise<Map<number, Deploy[]>> {
  const events = new Map();
  for (const domain of context.domainNumbers) {
    events.set(domain, await getDomainDeployedTokens(context, domain));
  }
  return events;
}

async function persistDeployedTokens(
  context: AbacusContext,
  credentials: string,
): Promise<void> {
  const deployed = await getDeployedTokens(context);
  for (let domain of deployed.keys()) {
    let domainName = context.resolveDomainName(domain);
    const tokens = deployed.get(domain);
    uploadDeployedTokens(domainName!, tokens!, credentials);
  }
  //
}

(async function main() {
  await persistDeployedTokens(mainnet, config.googleCredentialsFile);
})();