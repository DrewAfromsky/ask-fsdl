"""Run a Discord bot that does document Q&A using Modal and langchain."""
import argparse
import os

import aiohttp
import discord
from discord.ext import commands
from dotenv import load_dotenv
import requests

load_dotenv()

MODAL_USER_NAME = os.environ["MODAL_USER_NAME"]
BACKEND_URL = f"https://{MODAL_USER_NAME}--ask-fsdl-hook.modal.run"
DISCORD_AUTH = os.environ["DISCORD_AUTH"]

guild_ids = {
    "dev": 1070516629328363591,
    "prod": 984525101678612540,
}


async def runner(query):
    payload = {"query": query}
    async with aiohttp.ClientSession() as session:
        async with session.get(url=BACKEND_URL, params=payload) as response:
            assert response.status == 200
            json = await response.json()
            return json["answer"]


def main(auth, guilds, debug=False):
    # Discord auth requires statement of "intents"
    #  we start with default behaviors
    intents = discord.Intents.default()
    #  and add reading messages
    intents.message_content = True

    bot = commands.Bot(intents=intents, guilds=guilds)

    @bot.event
    async def on_ready():
        print(f"🤖: {bot.user} is ready and online!")

    response_fmt = \
    """{mention} asked: {question}

    Here's my best guess at an answer, with sources so you can read more:

    {response}"""

    # add our command
    @bot.slash_command(name="ask", description="Answers questions about FSDL material.")
    async def answer(ctx, question: str):
        """Answers questions about FSDL material."""
        respondent = ctx.author

        print(f"🤖: responding to question \"{question}\"")
        await ctx.respond("Working on it!", ephemeral=True)
        response = runner(question)  # execute
        await ctx.send_followup(response_fmt.format(mention=respondent.mention, question=question, response=response))  # respond

    if debug:
        @bot.slash_command()
        async def health(ctx):
            "Supports a Discord bot version of a liveness probe."
            print(f"🤖: inside foo")
            await ctx.respond("200 more like 💯 mirite")

    bot.run(auth)


def make_argparser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dev", action="store_true", help="Run in development mode.")
    parser.add_argument("--debug", action="store_true", help="Add debugging commands.")
    parser.add_argument("--monitor", action="store_true", help="Log bot behavior.")

    return parser


if __name__ == "__main__":
    args = make_argparser().parse_args()
    if args.dev:
        guilds = [guild_ids["dev"]]
    else:
        guilds = [guild_ids["prod"]]
    main(auth=DISCORD_AUTH, guilds=guilds, debug=args.dev or args.debug)
